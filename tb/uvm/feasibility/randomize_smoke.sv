// SPDX-License-Identifier: Apache-2.0
module randomize_smoke_top;
  class random_item;
    rand bit [7:0] payload;
    constraint payload_range { payload inside {[8'h10:8'hef]}; }
  endclass

  initial begin
    random_item item;
    item = new;
    if (item.randomize() == 0) $fatal(1, "randomization failed");
    if (!(item.payload inside {[8'h10:8'hef]})) $fatal(1, "constraint violated");
    $display("RANDOMIZE_SMOKE_COMPLETE payload=%0h", item.payload);
    $finish;
  end
endmodule
