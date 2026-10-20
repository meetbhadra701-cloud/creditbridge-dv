// SPDX-License-Identifier: Apache-2.0
// Immediate safety assertions usable in the open-source directed workflow.
module creditbridge_assertions #(
  parameter int MAX_CREDITS = 8
) (
  input logic clk,
  input logic rst,
  input logic m_link_valid,
  input logic m_link_credit_return,
  input logic [$clog2(MAX_CREDITS+1)-1:0] credits_available
);
  localparam int CREDIT_WIDTH = $clog2(MAX_CREDITS + 1);
  localparam logic [CREDIT_WIDTH-1:0] MAX_CREDITS_COUNT = CREDIT_WIDTH'(MAX_CREDITS);

  always @(posedge clk) begin
    if (!rst) begin
      assert (credits_available <= MAX_CREDITS_COUNT)
        else $fatal(1, "Credit count exceeded MAX_CREDITS");
      assert (!(m_link_valid && (credits_available == 0)))
        else $fatal(1, "Output transfer was attempted without a credit");
      assert (!(m_link_credit_return && (credits_available == MAX_CREDITS_COUNT) && !m_link_valid))
        else $fatal(1, "Illegal credit return while no credit is outstanding");
    end
  end
endmodule
