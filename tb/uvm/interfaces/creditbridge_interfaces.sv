// SPDX-License-Identifier: Apache-2.0
interface cb_axis_if #(parameter int DATA_WIDTH = 32) (input logic clk);
  localparam int KEEP_WIDTH = DATA_WIDTH / 8;
  logic rst;
  logic tvalid;
  logic tready;
  logic [DATA_WIDTH-1:0] tdata;
  logic [KEEP_WIDTH-1:0] tkeep;
  logic tlast;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output tvalid, tdata, tkeep, tlast;
    input tready, rst;
  endclocking
  // Monitor on the falling edge so signals are sampled mid-cycle, after
  // driver updates and before the next DUT transfer edge.  This avoids the
  // known Verilator clocking-block #1step ambiguity at a shared posedge.
  clocking mon_cb @(negedge clk);
    default input #1step;
    input rst, tvalid, tready, tdata, tkeep, tlast;
  endclocking
endinterface

interface cb_credit_if #(parameter int DATA_WIDTH = 32,
                         parameter int MAX_CREDITS = 8) (input logic clk);
  localparam int KEEP_WIDTH = DATA_WIDTH / 8;
  logic rst;
  logic valid;
  logic [DATA_WIDTH-1:0] data;
  logic [KEEP_WIDTH-1:0] keep;
  logic last;
  logic credit_return;
  logic [$clog2(MAX_CREDITS+1)-1:0] credits_available;

  clocking return_drv_cb @(posedge clk);
    default input #1step output #0;
    output credit_return;
    input rst;
  endclocking
  // See cb_axis_if.mon_cb: falling-edge observation gives a deterministic
  // view of the handshakes that will be consumed on the next rising edge.
  clocking mon_cb @(negedge clk);
    default input #1step;
    input rst, valid, data, keep, last, credit_return, credits_available;
  endclocking
endinterface
