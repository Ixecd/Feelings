// GW1N LED blinker — external 24MHz clk
module top(input clk, output l1, output l2);
    reg [23:0] cnt = 0;
    always @(posedge clk) cnt <= cnt + 1;
    assign l1 = cnt[23];
    assign l2 = cnt[22];
endmodule
