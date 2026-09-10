// pin_test.v — v5：区分 SCL/SDA 对应的孔
//   LED (ball39) → ~2.9Hz 闪
//   ball46 → 低 (0V)   ← 这是 SCL
//   ball44 → 高 (3.3V) ← 这是 SDA
// 量之前那两个 0V 孔：变 3.3V 的 = ball44(SDA)，仍 0V 的 = ball46(SCL)
`default_nettype none

module pin_test (
    output p6,
    output p46,
    output p44,
    output led
);
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    reg [23:0] c;
    always @(posedge clk) c <= c + 1'b1;

    assign led = ~c[23];
    assign p6  = 1'b1;
    assign p46 = 1'b0;   // SCL
    assign p44 = 1'b1;   // SDA
endmodule

`default_nettype wire
