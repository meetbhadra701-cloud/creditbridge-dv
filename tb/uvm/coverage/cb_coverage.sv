// Coverage is driven exclusively from observed interface events. It does not
// inspect DUT FIFO state; occupancy is accepted-minus-sent observer state.
class cb_coverage extends uvm_subscriber #(cb_axis_item);
  `uvm_component_utils(cb_coverage)
  virtual cb_axis_if axis_vif;
  virtual cb_credit_if credit_vif;
  bit [3:0] sampled_keep;
  int unsigned packet_length, sampled_packet_length;
  bit packet_complete;
  bit sampled_input_fire;
  int unsigned observed_occupancy, sampled_backpressure, active_backpressure;
  int unsigned sampled_credits;
  bit sampled_reset, sampled_simultaneous_io, sampled_simultaneous_send_return;

  covergroup protocol_cg;
    option.per_instance = 1;
    // TKEEP is meaningful only on an accepted AXI beat.  Idle and stalled
    // values must not contribute to transferred-data coverage.
    keep_cp: coverpoint sampled_keep iff (sampled_input_fire) {
      bins one_byte = {4'h1}; bins full_word = {4'hf};
      bins sparse = {4'h2, 4'h4, 4'h8}; bins mixed[] = {[4'h3:4'he]};
    }
    packet_length_cp: coverpoint sampled_packet_length iff (packet_complete) {
      bins single = {1}; bins short = {[2:3]}; bins len_mid = {[4:8]}; bins long = {[9:32]};
    }
    credits_cp: coverpoint sampled_credits iff (!sampled_reset) {
      bins exhausted = {0}; bins low = {[1:2]}; bins available = {[3:7]}; bins full = {8};
    }
    occupancy_cp: coverpoint observed_occupancy iff (!sampled_reset) {
      bins empty = {0}; bins near_empty = {1}; bins middle = {[2:7]}; bins full = {8};
    }
    backpressure_cp: coverpoint sampled_backpressure iff (sampled_backpressure != 0) {
      bins one = {1}; bins short = {[2:3]}; bins long = {[4:32]};
    }
    reset_cp: coverpoint sampled_reset { bins asserted = {1}; bins inactive = {0}; }
    simultaneous_io_cp: coverpoint sampled_simultaneous_io iff (!sampled_reset);
    simultaneous_send_return_cp: coverpoint sampled_simultaneous_send_return iff (!sampled_reset);
    packet_length_x_credit: cross packet_length_cp, credits_cp;
  endgroup

  function new(string name = "cb_coverage", uvm_component parent = null);
    super.new(name, parent); protocol_cg = new;
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual cb_axis_if)::get(this, "", "axis_vif", axis_vif))
      `uvm_fatal("NOVIF", "axis_vif was not configured for coverage")
    if (!uvm_config_db#(virtual cb_credit_if)::get(this, "", "credit_vif", credit_vif))
      `uvm_fatal("NOVIF", "credit_vif was not configured for coverage")
  endfunction
  // The interface clock is the canonical sampling clock. This subscriber hook
  // keeps the standard analysis connection but intentionally does not sample.
  function void write(cb_axis_item t); endfunction
  task run_phase(uvm_phase phase);
    bit input_fire, output_fire;
    forever begin
      @(posedge axis_vif.clk);
      sampled_reset = axis_vif.rst;
      sampled_backpressure = 0;
      packet_complete = 0;
      sampled_input_fire = 0;
      if (sampled_reset) begin
        packet_length = 0; observed_occupancy = 0; active_backpressure = 0;
        sampled_packet_length = 0; sampled_credits = 8; sampled_keep = '0;
        sampled_simultaneous_io = 0; sampled_simultaneous_send_return = 0;
      end else begin
        input_fire = axis_vif.tvalid && axis_vif.tready;
        output_fire = credit_vif.valid;
        sampled_input_fire = input_fire;
        sampled_keep = axis_vif.tkeep;
        sampled_credits = credit_vif.credits_available;
        sampled_simultaneous_io = input_fire && output_fire;
        sampled_simultaneous_send_return = output_fire && credit_vif.credit_return;
        if (axis_vif.tvalid && !axis_vif.tready) active_backpressure++;
        else if (active_backpressure != 0) begin
          sampled_backpressure = active_backpressure; active_backpressure = 0;
        end
        if (input_fire) begin
          packet_length++;
          if (axis_vif.tlast) begin
            sampled_packet_length = packet_length; packet_complete = 1; packet_length = 0;
            if ($test$plusargs("CB_COV_DEBUG"))
              `uvm_info("COV_PACKET", $sformatf("t=%0t len=%0d credits=%0d occupancy=%0d", $time, sampled_packet_length, sampled_credits, observed_occupancy), UVM_LOW)
          end
        end
        case ({input_fire, output_fire})
          2'b10: observed_occupancy++;
          2'b01: if (observed_occupancy != 0) observed_occupancy--;
          default: ;
        endcase
      end
      if ($test$plusargs("CB_COV_DEBUG") && sampled_backpressure != 0)
        `uvm_info("COV_BACKPRESSURE", $sformatf("t=%0t cycles=%0d", $time, sampled_backpressure), UVM_LOW)
      protocol_cg.sample();
    end
  endtask
endclass
