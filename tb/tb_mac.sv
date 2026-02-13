`timescale 1ns/1ps

module tb_mac;

  localparam int A_WIDTH   = 8;
  localparam int B_WIDTH   = 8;
  localparam int OUT_WIDTH = 18;

  localparam int N_SAMPLES             = 15;
  localparam int EOF_TO_RESULT_CYCLES  = 3;

  logic signed [A_WIDTH-1:0]   a;
  logic signed [B_WIDTH-1:0]   b;
  logic                        clk;
  logic                        reset;
  logic                        eof;
  logic signed [OUT_WIDTH-1:0] result;
  logic                        valid_in;
  logic                        valid_out;
  logic                        enable;

  localparam time CLK_PERIOD = 10ns;

  initial clk = 1'b0;
  always #(CLK_PERIOD/2) clk <= ~clk; // NB assignment to satisfy Verilator

  mac #(
    .A_WIDTH(A_WIDTH),
    .B_WIDTH(B_WIDTH),
    .OUT_WIDTH(OUT_WIDTH)
  ) dut (
    .a(a),
    .b(b),
    .clk(clk),
    .reset(reset),
    .eof(eof),
    .result(result),
    .valid_in(valid_in),
    .valid_out(valid_out),
    .enable(enable)
  );

  function automatic logic signed [OUT_WIDTH-1:0] expected_sum(input int n);
    longint signed acc;
    int i;
    begin
      acc = 0;
      for (i = 1; i <= n; i++) begin
        acc += (i * i);
      end
      expected_sum = $signed(acc[OUT_WIDTH-1:0]);
    end
  endfunction

  initial begin
    $dumpfile("sim/mac_sim.vcd");
    $dumpvars(0, tb_mac);
  end

  // Count valid_out pulses (sanity check)
  int valid_out_count = 0;
  always_ff @(posedge clk) begin
    if (reset) valid_out_count <= 0;
    else if (enable && valid_out) valid_out_count <= valid_out_count + 1;
  end

  initial begin : stim
    logic signed [OUT_WIDTH-1:0] exp;
    int i;

    exp = expected_sum(N_SAMPLES);

    enable   = 1'b0;
    reset    = 1'b1;
    valid_in = 1'b0;
    eof      = 1'b0;
    a        = '0;
    b        = '0;

    @(posedge clk);
    @(posedge clk);

    reset  = 1'b0;
    enable = 1'b1;

    for (i = 1; i <= N_SAMPLES; i++) begin
      @(posedge clk);
      valid_in = 1'b1;
      a = $signed(i[A_WIDTH-1:0]);
      b = $signed(i[B_WIDTH-1:0]);
      eof      = (i == N_SAMPLES);
    end

    @(posedge clk);
    valid_in = 1'b0;
    eof      = 1'b0;
    a        = '0;
    b        = '0;

    repeat (EOF_TO_RESULT_CYCLES) @(posedge clk);

    // Check final result
    if (result !== exp) begin
      $display("FAIL: MAC final result mismatch. Expected=%0d Got=%0d",
               $signed(exp), $signed(result));
      $finish(1);
    end

    // Sanity: We expect one valid_out per input sample (given enable=1 throughout)
    if (valid_out_count !== N_SAMPLES) begin
      $display("FAIL: valid_out pulse count mismatch. Expected=%0d Got=%0d",
               N_SAMPLES, valid_out_count);
      $finish(1);
    end

    $display("PASS: MAC final result matched. Expected=%0d Got=%0d (valid_out pulses=%0d)",
             $signed(exp), $signed(result), valid_out_count);
    $finish(0);
  end

endmodule
