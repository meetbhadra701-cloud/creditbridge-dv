// SPDX-License-Identifier: Apache-2.0
module creditbridge_uvm_top;
  import uvm_pkg::*;
  import creditbridge_uvm_pkg::*;
  logic clk = 0;
  logic rst = 1;
  always #5 clk = ~clk;

  cb_axis_if axis_if(clk);
  cb_credit_if #(.MAX_CREDITS(8)) credit_if(clk);
  assign axis_if.rst = rst;
  assign credit_if.rst = rst;

  credit_bridge #(.FIFO_DEPTH(8), .MAX_CREDITS(8)) dut (
    .clk, .rst,
    .s_axis_tvalid(axis_if.tvalid), .s_axis_tready(axis_if.tready),
    .s_axis_tdata(axis_if.tdata), .s_axis_tkeep(axis_if.tkeep), .s_axis_tlast(axis_if.tlast),
    .m_link_valid(credit_if.valid), .m_link_data(credit_if.data),
    .m_link_keep(credit_if.keep), .m_link_last(credit_if.last),
    .m_link_credit_return(credit_if.credit_return), .credits_available(credit_if.credits_available)
  );

  creditbridge_sva #(.MAX_CREDITS(8)) sva (
    .clk(clk), .rst(rst), .s_valid(axis_if.tvalid), .s_ready(axis_if.tready),
    .s_data(axis_if.tdata), .s_keep(axis_if.tkeep), .s_last(axis_if.tlast),
    .m_valid(credit_if.valid), .m_credit_return(credit_if.credit_return),
    .credits_available(credit_if.credits_available)
  );

  initial begin
    axis_if.tvalid = 0; axis_if.tdata = '0; axis_if.tkeep = '0; axis_if.tlast = 0;
    credit_if.credit_return = 0;
    repeat (2) @(negedge clk);
    rst = 0;
  end
  initial begin
    int reset_after, reset_cycles;
    if ($value$plusargs("CB_RESET_AFTER=%d", reset_after) &&
        $value$plusargs("CB_RESET_CYCLES=%d", reset_cycles)) begin
      repeat (reset_after) @(negedge clk);
      rst = 1;
      repeat (reset_cycles) @(negedge clk);
      rst = 0;
    end
  end
  initial begin
    uvm_config_db#(virtual cb_axis_if)::set(null, "uvm_test_top.env.axis_agent*", "vif", axis_if);
    uvm_config_db#(virtual cb_axis_if)::set(null, "uvm_test_top.env.scoreboard", "axis_vif", axis_if);
    uvm_config_db#(virtual cb_credit_if)::set(null, "uvm_test_top.env.scoreboard", "credit_vif", credit_if);
    uvm_config_db#(virtual cb_axis_if)::set(null, "uvm_test_top.env.coverage", "axis_vif", axis_if);
    uvm_config_db#(virtual cb_credit_if)::set(null, "uvm_test_top.env.credit_agent*", "vif", credit_if);
    uvm_config_db#(virtual cb_credit_if)::set(null, "uvm_test_top.env.credit_responder", "vif", credit_if);
    uvm_config_db#(virtual cb_credit_if)::set(null, "uvm_test_top.env.coverage", "credit_vif", credit_if);
    run_test();
  end
endmodule
