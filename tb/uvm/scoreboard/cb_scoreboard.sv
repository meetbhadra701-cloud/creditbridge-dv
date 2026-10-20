class cb_scoreboard extends uvm_component;
  `uvm_component_utils(cb_scoreboard)
  virtual cb_axis_if axis_vif;
  virtual cb_credit_if credit_vif;
  uvm_tlm_analysis_fifo #(cb_axis_item) input_fifo;
  uvm_tlm_analysis_fifo #(cb_link_item) output_fifo;
  cb_axis_item expected_q[$];
  int unsigned accepted_inputs;
  int unsigned observed_outputs;
  time last_reset_time;

  function new(string name = "cb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    input_fifo = new("input_fifo", this);
    output_fifo = new("output_fifo", this);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual cb_axis_if)::get(this, "", "axis_vif", axis_vif))
      `uvm_fatal("NOVIF", "axis_vif was not configured")
    if (!uvm_config_db#(virtual cb_credit_if)::get(this, "", "credit_vif", credit_vif))
      `uvm_fatal("NOVIF", "credit_vif was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    cb_axis_item in_tr;
    cb_axis_item exp_tr;
    forever begin
      @(posedge axis_vif.clk);
      // Sample raw interface values in the active region before NBA updates.
      // This is the single reference-model sampling point; analysis FIFO
      // callbacks are intentionally not used for comparison because separate
      // monitor processes may publish in different delta cycles.
      if (axis_vif.rst) begin
        last_reset_time = $time;
        expected_q.delete();
        if ($test$plusargs("CB_DEBUG")) `uvm_info("SB_RESET", $sformatf("reset at %0t", $time), UVM_LOW)
        // Keep analysis FIFOs bounded; their connections remain useful for
        // component-level observability but do not determine checker order.
        while (input_fifo.try_get(in_tr));
      end else begin
        if (axis_vif.tvalid && axis_vif.tready) begin
          in_tr = cb_axis_item::type_id::create("scoreboard_input");
          in_tr.data = axis_vif.tdata;
          in_tr.keep = axis_vif.tkeep;
          in_tr.last = axis_vif.tlast;
          in_tr.sample_time = $time;
          expected_q.push_back(in_tr);
          accepted_inputs++;
          if ($test$plusargs("CB_DEBUG")) `uvm_info("SB_INPUT", $sformatf("t=%0t data=%08h last=%0b q=%0d", $time, in_tr.data, in_tr.last, expected_q.size()), UVM_LOW)
        end
        if (credit_vif.valid) begin
          observed_outputs++;
          if ($test$plusargs("CB_DEBUG")) `uvm_info("SB_OUTPUT", $sformatf("t=%0t data=%08h last=%0b q=%0d", $time, credit_vif.data, credit_vif.last, expected_q.size()), UVM_LOW)
          if (expected_q.size() == 0) begin
            `uvm_error("SB_UNEXPECTED", "Output observed with no accepted input")
          end else begin
            exp_tr = expected_q.pop_front();
            if ({credit_vif.data, credit_vif.keep, credit_vif.last} !== {exp_tr.data, exp_tr.keep, exp_tr.last})
              `uvm_error("SB_MISMATCH", $sformatf("got %08h/%h/%b expected %08h/%h/%b",
                credit_vif.data, credit_vif.keep, credit_vif.last,
                exp_tr.data, exp_tr.keep, exp_tr.last))
          end
        end
      end
    end
  endtask
  task wait_for_drain(int unsigned max_cycles);
    int unsigned cycles = 0;
    // Give monitors one cycle after the final driven handshake.
    repeat (2) @(posedge axis_vif.clk);
    while ((expected_q.size() != 0) && (cycles < max_cycles)) begin
      @(posedge axis_vif.clk); cycles++;
    end
    if (expected_q.size() != 0)
      `uvm_error("SB_TIMEOUT", $sformatf("%0d expected beats did not drain", expected_q.size()))
  endtask
  function void check_phase(uvm_phase phase);
    `uvm_info("SB_ACTIVITY", $sformatf("accepted_inputs=%0d observed_outputs=%0d pending=%0d",
      accepted_inputs, observed_outputs, expected_q.size()), UVM_LOW)
    if (accepted_inputs == 0)
      `uvm_error("SB_NO_INPUT_ACTIVITY", "No accepted AXI input beats were observed")
    if (observed_outputs == 0)
      `uvm_error("SB_NO_OUTPUT_ACTIVITY", "No output beats were observed")
    if (expected_q.size() != 0)
      `uvm_error("SB_UNDRAINED", $sformatf("%0d beats remain at end of test", expected_q.size()))
  endfunction
endclass
