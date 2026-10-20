// SPDX-License-Identifier: Apache-2.0
// Simplified, independently specified credit-based packet bridge.
module credit_bridge #(
  parameter int DATA_WIDTH  = 32,
  parameter int KEEP_WIDTH  = DATA_WIDTH / 8,
  parameter int FIFO_DEPTH  = 8,
  parameter int MAX_CREDITS = FIFO_DEPTH
) (
  input  logic                         clk,
  input  logic                         rst,

  input  logic                         s_axis_tvalid,
  output logic                         s_axis_tready,
  input  logic [DATA_WIDTH-1:0]        s_axis_tdata,
  input  logic [KEEP_WIDTH-1:0]        s_axis_tkeep,
  input  logic                         s_axis_tlast,

  output logic                         m_link_valid,
  output logic [DATA_WIDTH-1:0]        m_link_data,
  output logic [KEEP_WIDTH-1:0]        m_link_keep,
  output logic                         m_link_last,
  input  logic                         m_link_credit_return,
  output logic [$clog2(MAX_CREDITS+1)-1:0] credits_available
);

  localparam int PTR_WIDTH   = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
  localparam int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);
  localparam int CREDIT_WIDTH = $clog2(MAX_CREDITS + 1);
  localparam logic [PTR_WIDTH-1:0] FIFO_LAST_PTR = PTR_WIDTH'(FIFO_DEPTH - 1);
  localparam logic [COUNT_WIDTH-1:0] FIFO_DEPTH_COUNT = COUNT_WIDTH'(FIFO_DEPTH);
  localparam logic [CREDIT_WIDTH-1:0] MAX_CREDITS_COUNT = CREDIT_WIDTH'(MAX_CREDITS);

  logic [DATA_WIDTH-1:0] data_mem [0:FIFO_DEPTH-1];
  logic [KEEP_WIDTH-1:0] keep_mem [0:FIFO_DEPTH-1];
  logic                  last_mem [0:FIFO_DEPTH-1];
  logic [PTR_WIDTH-1:0]  wr_ptr;
  logic [PTR_WIDTH-1:0]  rd_ptr;
  logic [COUNT_WIDTH-1:0] fifo_count;
  logic [CREDIT_WIDTH-1:0] credit_count;
  logic input_fire;
  logic output_fire;

`ifndef SYNTHESIS
  initial begin
    if (DATA_WIDTH <= 0 || KEEP_WIDTH <= 0 || FIFO_DEPTH <= 0 || MAX_CREDITS <= 0) begin
      $fatal(1, "All CreditBridge parameters must be positive");
    end
    if ((DATA_WIDTH % 8) != 0 || KEEP_WIDTH != (DATA_WIDTH / 8)) begin
      $fatal(1, "KEEP_WIDTH must equal DATA_WIDTH / 8");
    end
  end
`endif

  // A full FIFO can accept a beat only when the current cycle also sends one.
  assign m_link_valid = (fifo_count != 0) && (credit_count != 0);
  assign output_fire = m_link_valid;
  assign s_axis_tready = (fifo_count < FIFO_DEPTH_COUNT) || output_fire;
  assign input_fire = s_axis_tvalid && s_axis_tready;

  assign m_link_data = data_mem[rd_ptr];
  assign m_link_keep = keep_mem[rd_ptr];
  assign m_link_last = last_mem[rd_ptr];
  assign credits_available = credit_count;

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr       <= '0;
      rd_ptr       <= '0;
      fifo_count   <= '0;
      credit_count <= MAX_CREDITS[CREDIT_WIDTH-1:0];
    end else begin
      if (input_fire) begin
        data_mem[wr_ptr] <= s_axis_tdata;
        keep_mem[wr_ptr] <= s_axis_tkeep;
        last_mem[wr_ptr] <= s_axis_tlast;
        if (wr_ptr == FIFO_LAST_PTR)
          wr_ptr <= '0;
        else
          wr_ptr <= wr_ptr + 1'b1;
      end

      if (output_fire) begin
        if (rd_ptr == FIFO_LAST_PTR)
          rd_ptr <= '0;
        else
          rd_ptr <= rd_ptr + 1'b1;
      end

      unique case ({input_fire, output_fire})
        2'b10: fifo_count <= fifo_count + 1'b1;
        2'b01: fifo_count <= fifo_count - 1'b1;
        default: fifo_count <= fifo_count;
      endcase

      unique case ({output_fire, m_link_credit_return})
        2'b10: credit_count <= credit_count - 1'b1;
        2'b01: begin
          // An over-return is an environment protocol violation. Saturation
          // keeps the hardware state bounded while assertions flag it in DV.
          if (credit_count < MAX_CREDITS_COUNT)
            credit_count <= credit_count + 1'b1;
          else
            credit_count <= credit_count;
        end
        default: credit_count <= credit_count;
      endcase
    end
  end
endmodule
