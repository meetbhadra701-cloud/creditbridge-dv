// SPDX-License-Identifier: Apache-2.0
// This probe must fail when executed with --assert.  The recovery harness
// treats a zero exit code as an assertion-execution failure.
module sva_failure_smoke_top;
  logic clk = 0;
  logic valid = 0;
  logic data = 0;
  always #5 clk = ~clk;

  property p_valid_implies_data;
    @(posedge clk) valid |-> data;
  endproperty
  assert property (p_valid_implies_data)
    else $error("SVA_FAILURE_SMOKE: intentional assertion failure observed");

  initial begin
    @(negedge clk);
    valid = 1;
    data = 0;
    @(posedge clk);
    #1;
    $finish;
  end
endmodule
