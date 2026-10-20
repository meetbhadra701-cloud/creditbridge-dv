// SPDX-License-Identifier: Apache-2.0
// Standalone probe for virtual-interface access through a clocking block.
// It deliberately exercises the construct relevant to Verilator issue #7688.
interface vi_clocking_probe_if(input logic clk);
  logic drive_value;
  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output drive_value;
  endclocking
  clocking mon_cb @(posedge clk);
    default input #1step;
    input drive_value;
  endclocking
endinterface

module virtual_if_clocking_smoke_top;
  logic clk = 0;
  always #5 clk = ~clk;
  vi_clocking_probe_if probe_if(clk);
  virtual vi_clocking_probe_if vif;

  initial begin
    vif = probe_if;
    vif.drv_cb.drive_value <= 0;
    @(vif.drv_cb);
    vif.drv_cb.drive_value <= 1;
    @(vif.mon_cb);
    if (vif.mon_cb.drive_value !== 1)
      $fatal(1, "Virtual-interface clocking-block propagation failed");
    $display("VIRTUAL_IF_CLOCKING_SMOKE_COMPLETE");
    $finish;
  end
endmodule
