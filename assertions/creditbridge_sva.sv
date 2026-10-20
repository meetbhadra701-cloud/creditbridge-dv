// SPDX-License-Identifier: Apache-2.0
// Concurrent assertions for UVM-capable simulators. Bind in the UVM top.
module creditbridge_sva #(
  parameter int DATA_WIDTH = 32,
  parameter int KEEP_WIDTH = DATA_WIDTH / 8,
  parameter int MAX_CREDITS = 8
) (
  input logic clk, rst,
  input logic s_valid, s_ready,
  input logic [DATA_WIDTH-1:0] s_data,
  input logic [KEEP_WIDTH-1:0] s_keep,
  input logic s_last,
  input logic m_valid,
  input logic m_credit_return,
  input logic [$clog2(MAX_CREDITS+1)-1:0] credits_available
);
  property p_input_stable_when_stalled;
    @(posedge clk) disable iff (rst)
      s_valid && !s_ready |=> s_valid && $stable({s_data, s_keep, s_last});
  endproperty
  assert property (p_input_stable_when_stalled);

  property p_output_requires_credit;
    @(posedge clk) disable iff (rst) m_valid |-> (credits_available > 0);
  endproperty
  assert property (p_output_requires_credit);

  property p_no_idle_overreturn;
    @(posedge clk) disable iff (rst)
      m_credit_return && !m_valid |-> (credits_available < MAX_CREDITS);
  endproperty
  assert property (p_no_idle_overreturn);

  property p_reset_restores_credit;
    @(posedge clk) rst |=> (credits_available == MAX_CREDITS);
  endproperty
  assert property (p_reset_restores_credit);

  property p_credit_count_range;
    @(posedge clk) disable iff (rst)
      credits_available <= MAX_CREDITS;
  endproperty
  assert property (p_credit_count_range);
endmodule
