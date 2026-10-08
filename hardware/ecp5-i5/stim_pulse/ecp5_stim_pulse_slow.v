// ecp5_stim_pulse_slow.v — tVNS 双相脉冲发生器（慢速 bench 版，用于示波器观察）
//   与 ecp5_stim_pulse.v 逻辑完全相同，仅把时序放慢：
//     周期 5Hz（200ms）；每相 20ms；死区 2ms
//   目的：摆脱 25Hz/200µs 下"触发难、脉冲太窄"的观察问题，看清稳态波形。
//   引脚与主版一致：clk=P3, en=E17, in1=D16, in2=D17, led=U16（沿用同一 .lpf）
`default_nettype none

module ecp5_stim_pulse_slow (
    input  wire clk,      // 25MHz (P3)
    output reg  en,       // 默认低 = 上电安全态
    output reg  in1,
    output reg  in2,
    output wire led
);
    localparam integer CLK_HZ = 25_000_000;
    localparam integer PERIOD = CLK_HZ / 5;      // 5Hz   → 5_000_000 周期 (200ms)
    localparam integer PW     = CLK_HZ / 50;     // 20ms  → 500_000 周期
    localparam integer D      = CLK_HZ / 500;    // 2ms   → 50_000 周期

    localparam integer T1 = PW;                  // 正相结束
    localparam integer T2 = T1 + D;              // 死区结束
    localparam integer T3 = T2 + PW;             // 负相结束

    reg [31:0] cnt;
    reg        act;

    initial begin
        cnt = 32'd0; en = 1'b0; in1 = 1'b0; in2 = 1'b0; act = 1'b0;
    end

    always @(posedge clk)
        cnt <= (cnt >= PERIOD - 1) ? 32'd0 : cnt + 32'd1;

    always @(posedge clk) begin
        if      (cnt < T1) begin en <= 1'b1; in1 <= 1'b1; in2 <= 1'b0; end // 正相 20ms
        else if (cnt < T2) begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b0; end // 死区 2ms
        else if (cnt < T3) begin en <= 1'b1; in1 <= 1'b0; in2 <= 1'b1; end // 负相 20ms
        else               begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b0; end // 停
    end

    always @(posedge clk) begin
        if      (cnt == 32'd0)        act <= 1'b1;
        else if (cnt == PERIOD / 2)   act <= 1'b0;
    end
    assign led = act;
endmodule

`default_nettype wire
