// SPDX-License-Identifier: Apache-2.0
// Kept independent so a covergroup compiler failure is not mistaken for UVM.
module covergroup_smoke_top;
  bit [1:0] value;
  covergroup value_cg;
    option.per_instance = 1;
    value_cp: coverpoint value { bins all_values[] = {[0:3]}; }
  endgroup
  value_cg cg = new;

  initial begin
    for (int i = 0; i < 4; i++) begin
      value = i[1:0];
      cg.sample();
    end
    $display("COVERGROUP_SMOKE_COMPLETE coverage=%0.2f", cg.get_inst_coverage());
    $finish;
  end
endmodule
