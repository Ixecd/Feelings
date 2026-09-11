`timescale 1ns/1ps
`default_nettype none
module tb_ping;
    wire clk, tx, led;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));
    uart_ping dut (.tx(tx), .led(led));
    localparam BIT = 1250;   // DUT BAUD=9600 @12MHz
    integer ucnt=0; reg [3:0] ubit=0; reg [7:0] ush=0; reg [2:0] ust=0; reg txq=1; integer rcnt=0;
    always @(posedge clk) txq<=tx;
    always @(posedge clk) begin
        case(ust)
        3'd0: if (txq && !tx) begin ust<=1; ucnt<=0; end
        3'd1: if (ucnt==BIT/2-1) begin ust<=2; ucnt<=0; ubit<=0; end else ucnt<=ucnt+1;
        3'd2: if (ucnt==BIT-1) begin ucnt<=0; ush[ubit]<=tx; if(ubit==7) ust<=3; else ubit<=ubit+1; end else ucnt<=ucnt+1;
        3'd3: if (ucnt==BIT-1) begin ucnt<=0; ust<=0; $display("  byte #%0d = 0x%02x", rcnt, ush); rcnt<=rcnt+1; if(rcnt==9) begin $display(">>> end"); $finish; end end else ucnt<=ucnt+1;
        endcase
    end
    initial begin #50_000_000; $display("!!! timeout"); $finish; end
endmodule
`default_nettype wire
