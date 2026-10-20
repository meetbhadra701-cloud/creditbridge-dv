// SPDX-License-Identifier: Apache-2.0
// Deterministic self-checking harness.  The queue models only accepted
// transactions, not DUT FIFO pointers/counts or credit-update implementation.
module tb_credit_bridge #(
  parameter int FIFO_DEPTH = 8,
  parameter int MAX_CREDITS = 4
);
  localparam int DATA_WIDTH = 32;
  localparam int KEEP_WIDTH = DATA_WIDTH / 8;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [KEEP_WIDTH-1:0] keep;
    logic                  last;
  } beat_t;

  logic clk = 1'b0;
  logic rst = 1'b0;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic [DATA_WIDTH-1:0] s_axis_tdata;
  logic [KEEP_WIDTH-1:0] s_axis_tkeep;
  logic s_axis_tlast;
  logic m_link_valid;
  logic [DATA_WIDTH-1:0] m_link_data;
  logic [KEEP_WIDTH-1:0] m_link_keep;
  logic m_link_last;
  logic m_link_credit_return;
  logic [$clog2(MAX_CREDITS+1)-1:0] credits_available;

  beat_t expected_q[$];
  int failures = 0;
  int tests_run = 0;
  int tests_passed = 0;
  int output_beats = 0;
  bit auto_return = 0;
  int pending_auto_returns = 0;
  int pending_manual_returns = 0;
  string selected_test;
  string vcd_file;

  credit_bridge #(
    .DATA_WIDTH(DATA_WIDTH), .KEEP_WIDTH(KEEP_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH), .MAX_CREDITS(MAX_CREDITS)
  ) dut (.*);

  creditbridge_assertions #(.MAX_CREDITS(MAX_CREDITS)) assertions (.*);

  always #5 clk = ~clk;

  // Independent input/output stream checker.  It records only externally
  // accepted input beats and compares each emitted beat in order.
  always @(posedge clk) begin : transaction_checker
    beat_t expected;
    if (rst) begin
      expected_q.delete();
      pending_auto_returns = 0;
      pending_manual_returns = 0;
    end else begin
      if (s_axis_tvalid && s_axis_tready) begin
        expected.data = s_axis_tdata;
        expected.keep = s_axis_tkeep;
        expected.last = s_axis_tlast;
        expected_q.push_back(expected);
      end
      if (m_link_valid) begin
        output_beats++;
        if (expected_q.size() == 0) begin
          failures++;
          $error("Checker: output beat with no accepted input beat");
        end else begin
          expected = expected_q.pop_front();
          if ({m_link_data, m_link_keep, m_link_last} !==
              {expected.data, expected.keep, expected.last}) begin
            failures++;
            $error("Checker: output mismatch got %h/%h/%b expected %h/%h/%b",
                   m_link_data, m_link_keep, m_link_last,
                   expected.data, expected.keep, expected.last);
          end
        end
        if (auto_return)
          pending_auto_returns++;
      end
    end
  end

  // The optional receiver model returns each consumed credit one full cycle
  // later.  Manual-credit tests disable this behavior.
  always @(negedge clk) begin
    if (rst) begin
      m_link_credit_return <= 1'b0;
    end else if (pending_manual_returns > 0) begin
      m_link_credit_return <= 1'b1;
      pending_manual_returns--;
    end else if (auto_return && (pending_auto_returns > 0)) begin
      m_link_credit_return <= 1'b1;
      pending_auto_returns--;
    end else begin
      m_link_credit_return <= 1'b0;
    end
  end

  task automatic reset_dut;
    begin
      auto_return = 0;
      @(negedge clk);
      s_axis_tvalid = 0;
      s_axis_tdata = '0;
      s_axis_tkeep = '0;
      s_axis_tlast = 0;
      pending_manual_returns = 0;
      rst = 1;
      @(posedge clk);
      @(negedge clk);
      rst = 0;
    end
  endtask

  task automatic send_beat(input logic [DATA_WIDTH-1:0] data,
                           input logic [KEEP_WIDTH-1:0] keep,
                           input logic last);
    bit accepted;
    begin
      accepted = 0;
      @(negedge clk);
      s_axis_tvalid = 1;
      s_axis_tdata = data;
      s_axis_tkeep = keep;
      s_axis_tlast = last;
      while (!accepted) begin
        @(posedge clk);
        if (s_axis_tready)
          accepted = 1;
      end
      @(negedge clk);
      s_axis_tvalid = 0;
    end
  endtask

  task automatic pulse_credit_return;
    begin
      pending_manual_returns++;
      // Wait for the receiver arbiter to drive the pulse and for the DUT to
      // sample it; callers can then inspect the replenished credit state.
      @(negedge clk);
      @(posedge clk);
      @(negedge clk);
    end
  endtask

  task automatic wait_for_drain(input int max_cycles);
    int cycles;
    begin
      cycles = 0;
      while ((expected_q.size() != 0) && (cycles < max_cycles)) begin
        @(posedge clk);
        cycles++;
      end
      if (expected_q.size() != 0) begin
        failures++;
        $error("Timed out draining %0d expected beats", expected_q.size());
      end
      // Allow the final checker pop to settle before a scenario reports.
      @(negedge clk);
    end
  endtask

  task automatic begin_test(input string name);
    begin
      tests_run++;
      $display("[RUN ] %s (FIFO_DEPTH=%0d)", name, FIFO_DEPTH);
      reset_dut();
    end
  endtask

  task automatic end_test(input string name, input int failures_at_start);
    begin
      if (failures == failures_at_start) begin
        tests_passed++;
        $display("[PASS] %s", name);
      end else begin
        $display("[FAIL] %s", name);
      end
    end
  endtask

  task automatic run_single_beat;
    int failures_at_start;
    begin failures_at_start = failures; begin_test("single_beat"); auto_return = 1;
      send_beat(32'h1000_0001, 4'hf, 1); wait_for_drain(20);
      end_test("single_beat", failures_at_start); end
  endtask

  task automatic run_multi_beat;
    int failures_at_start;
    begin failures_at_start = failures; begin_test("multi_beat"); auto_return = 1;
      send_beat(32'h2000_0001, 4'hf, 0); send_beat(32'h2000_0002, 4'h3, 0);
      send_beat(32'h2000_0003, 4'h1, 1); wait_for_drain(30);
      end_test("multi_beat", failures_at_start); end
  endtask

  task automatic run_fifo_empty;
    int failures_at_start;
    begin failures_at_start = failures; begin_test("fifo_empty");
      repeat (3) @(posedge clk);
      if (m_link_valid || (s_axis_tready !== 1'b1)) begin
        failures++; $error("Empty FIFO flags are incorrect");
      end
      end_test("fifo_empty", failures_at_start); end
  endtask

  task automatic run_fifo_full;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("fifo_full");
      // First MAX_CREDITS beats leave the link out of credits; the next
      // FIFO_DEPTH beats must occupy the storage exactly.
      for (i = 0; i < MAX_CREDITS + FIFO_DEPTH; i++)
        send_beat(32'h4000_0000 + i, 4'hf, (i == MAX_CREDITS + FIFO_DEPTH - 1));
      @(negedge clk);
      if (s_axis_tready !== 1'b0) begin failures++; $error("FIFO did not backpressure when full"); end
      auto_return = 1;
      pulse_credit_return();
      wait_for_drain(80);
      end_test("fifo_full", failures_at_start); end
  endtask

  task automatic run_input_backpressure;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("input_backpressure");
      for (i = 0; i < MAX_CREDITS + FIFO_DEPTH; i++)
        send_beat(32'h5000_0000 + i, 4'hf, (i == MAX_CREDITS + FIFO_DEPTH - 1));
      @(negedge clk);
      if (s_axis_tready !== 1'b0) begin failures++; $error("Input backpressure was not asserted"); end
      auto_return = 1; pulse_credit_return(); wait_for_drain(80);
      end_test("input_backpressure", failures_at_start); end
  endtask

  task automatic run_credit_exhaustion;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("credit_exhaustion");
      for (i = 0; i < MAX_CREDITS; i++) send_beat(32'h6000_0000 + i, 4'hf, 0);
      repeat (3) @(posedge clk);
      if ((credits_available != 0) || m_link_valid) begin
        failures++; $error("Credit exhaustion did not suppress output");
      end
      end_test("credit_exhaustion", failures_at_start); end
  endtask

  task automatic run_credit_replenishment;
    int failures_at_start; int i; int outputs_at_start; int cycles;
    begin failures_at_start = failures; begin_test("credit_replenishment");
      // Leave one accepted beat buffered after all initial credits are spent.
      for (i = 0; i <= MAX_CREDITS; i++) send_beat(32'h7000_0000 + i, 4'hf, (i == MAX_CREDITS));
      repeat (2) @(posedge clk);
      auto_return = 1;
      outputs_at_start = output_beats;
      pulse_credit_return();
      cycles = 0;
      while ((output_beats == outputs_at_start) && (cycles < 5)) begin
        @(posedge clk);
        cycles++;
      end
      if (output_beats == outputs_at_start) begin
        failures++; $error("Credit return did not re-enable output");
      end
      wait_for_drain(40);
      end_test("credit_replenishment", failures_at_start); end
  endtask

  task automatic run_simultaneous_io;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("simultaneous_io"); auto_return = 1;
      for (i = 0; i < 24; i++) send_beat(32'h8000_0000 + i, i[3:0], (i % 5 == 4));
      wait_for_drain(100); end_test("simultaneous_io", failures_at_start); end
  endtask

  task automatic run_reset_active_packet;
    int failures_at_start;
    begin failures_at_start = failures; begin_test("reset_active_packet");
      send_beat(32'h9000_0001, 4'hf, 0);
      @(negedge clk); s_axis_tvalid = 1; s_axis_tdata = 32'h9000_0002; s_axis_tkeep = 4'hf; s_axis_tlast = 1;
      rst = 1;
      @(posedge clk);
      @(negedge clk); rst = 0; s_axis_tvalid = 0;
      auto_return = 1;
      send_beat(32'h9000_0003, 4'h7, 1); wait_for_drain(30);
      end_test("reset_active_packet", failures_at_start); end
  endtask

  task automatic run_long_packet_sequences;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("long_packet_sequences"); auto_return = 1;
      for (i = 0; i < 64; i++) send_beat(32'ha000_0000 + i, 4'hf, (i % 16 == 15));
      wait_for_drain(200); end_test("long_packet_sequences", failures_at_start); end
  endtask

  task automatic run_fifo_depths;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("fifo_depths"); auto_return = 1;
      for (i = 0; i < (FIFO_DEPTH * 3 + 1); i++)
        send_beat(32'hb000_0000 + i, 4'hf, (i == FIFO_DEPTH * 3));
      wait_for_drain(100); end_test("fifo_depths", failures_at_start); end
  endtask

  task automatic run_ordering_preservation;
    int failures_at_start; int i;
    begin failures_at_start = failures; begin_test("ordering_preservation"); auto_return = 1;
      for (i = 0; i < 32; i++) send_beat(32'hc000_0000 + i, KEEP_WIDTH'((i % 4) + 1), (i % 7 == 6));
      wait_for_drain(160); end_test("ordering_preservation", failures_at_start); end
  endtask

  task automatic run_selected(input string name);
    begin
      if (name == "single_beat") run_single_beat();
      else if (name == "multi_beat") run_multi_beat();
      else if (name == "fifo_empty") run_fifo_empty();
      else if (name == "fifo_full") run_fifo_full();
      else if (name == "input_backpressure") run_input_backpressure();
      else if (name == "credit_exhaustion") run_credit_exhaustion();
      else if (name == "credit_replenishment") run_credit_replenishment();
      else if (name == "simultaneous_io") run_simultaneous_io();
      else if (name == "reset_active_packet") run_reset_active_packet();
      else if (name == "long_packet_sequences") run_long_packet_sequences();
      else if (name == "fifo_depths") run_fifo_depths();
      else if (name == "ordering_preservation") run_ordering_preservation();
      else begin failures++; $error("Unknown TEST=%s", name); end
    end
  endtask

  initial begin
    s_axis_tvalid = 0; s_axis_tdata = '0; s_axis_tkeep = '0; s_axis_tlast = 0;
    m_link_credit_return = 0;
    if ($value$plusargs("VCD=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb_credit_bridge);
    end
    if (!$value$plusargs("TEST=%s", selected_test)) selected_test = "all";
    if (selected_test == "all") begin
      run_single_beat(); run_multi_beat(); run_fifo_empty(); run_fifo_full();
      run_input_backpressure(); run_credit_exhaustion(); run_credit_replenishment();
      run_simultaneous_io(); run_reset_active_packet(); run_long_packet_sequences();
      run_fifo_depths(); run_ordering_preservation();
    end else begin
      run_selected(selected_test);
    end
    if ((failures == 0) && (tests_passed == tests_run)) begin
      $display("SUMMARY: %0d/%0d directed scenarios PASSED", tests_passed, tests_run);
      $finish;
    end else begin
      $fatal(1, "SUMMARY: %0d/%0d directed scenarios passed; %0d checker failures", tests_passed, tests_run, failures);
    end
  end
endmodule
