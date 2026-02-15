`timescale 1ns/1ps

module mac #(
  parameter int A_WIDTH   = 8,
  parameter int B_WIDTH   = 8,
  parameter int OUT_WIDTH = 18
) (
  input  logic signed [A_WIDTH-1:0]   a,
  input  logic signed [B_WIDTH-1:0]   b,
  input  logic                        clk,
  input  logic                        reset,     // synchronous, active high
  input  logic                        eof,       // marks last frame sample
  output logic signed [OUT_WIDTH-1:0] result,
  input  logic                        valid_in,
  output logic                        valid_out, // corresponds to stage1 valid (valid_r2)
  input  logic                        enable
);

  localparam int PROD_W = A_WIDTH + B_WIDTH;

  logic signed [A_WIDTH-1:0]          a_r;
  logic signed [B_WIDTH-1:0]          b_r;
  logic signed [PROD_W-1:0]           prod_r;
  logic signed [OUT_WIDTH-1:0]        sum_r;

  logic valid_r1, valid_r2;
  logic eof_r1, eof_r2, eof_r3;

  // Sign-extend product to OUT_WIDTH (assumes OUT_WIDTH >= PROD_W; true for 18 >= 16)
  logic signed [OUT_WIDTH-1:0] prod_ext;
  always_comb begin
    prod_ext = {{(OUT_WIDTH-PROD_W){prod_r[PROD_W-1]}}, prod_r};
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      sum_r    <= '0;
      valid_r1 <= 1'b0;
      valid_r2 <= 1'b0;
      eof_r1   <= 1'b0;
      eof_r2   <= 1'b0;
      eof_r3   <= 1'b1;  // first valid sample starts a fresh frame
      a_r      <= '0;
      b_r      <= '0;
      prod_r   <= '0;
    end else if (enable) begin
      // Stage 0: register inputs + valid/eof
      a_r      <= a;
      b_r      <= b;
      valid_r1 <= valid_in;
      eof_r1   <= eof;

      // Stage 1: register product + valid/eof
      prod_r   <= a_r * b_r;
      valid_r2 <= valid_r1;
      eof_r2   <= eof_r1;

      // Stage 2: accumulate
      if (valid_r2) begin
        if (eof_r3) begin
          sum_r <= prod_ext;         // new frame starts here
        end else begin
          sum_r <= sum_r + prod_ext; // keep accumulating
        end
        eof_r3 <= eof_r2;            // pending clear between frames
      end
    end
  end

  assign result    = sum_r;
  assign valid_out = valid_r2;

endmodule
