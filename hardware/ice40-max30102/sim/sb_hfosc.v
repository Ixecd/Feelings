// sb_hfosc.v — SB_HFOSC 仿真桩（不可综合）
`timescale 1ns/1ps
`default_nettype none

module SB_HFOSC #(
    parameter CLKHF_DIV = "0b00"
) (
    input  wire CLKHFPU,
    input  wire CLKHFEN,
    output reg  CLKHF
);
    initial CLKHF = 1'b0;
    always #20 CLKHF = ~CLKHF;   // 25MHz
endmodule

`default_nettype wire
