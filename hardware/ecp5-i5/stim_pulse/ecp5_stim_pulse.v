// ecp5_stim_pulse.v — tVNS 双相脉冲发生器（Colorlight i5 / ECP5-25F）
//   输出 IN1/IN2 → (2× ISO7721 隔离, 各用其正向通道B) → L293D H桥 → 恒流源 → 电极
//   ★ 2 线方案: L293D EN1 接隔离侧 VCC(常使能), 极性由 IN1/IN2 定
//     (IN1,IN2) = (1,0)正相 / (0,0)停 / (0,1)负相 —— 死区走 (0,0) 即安全中间态
//   参数: 频率 25Hz, 脉宽 200µs/相, 死区 10µs
//   时钟 25MHz (i5 P3) | LED=U16 刺激活动指示
//   注: 后期 EN1 应改接【硬件安全比较器】输出(而不是 VCC), 让安全层能硬关 H 桥
`default_nettype none

module ecp5_stim_pulse (
    input  wire clk,      // 25MHz (P3)
    output reg  in1,      // → L293D IN1（经隔离）
    output reg  in2,      // → L293D IN2（经隔离）
    output wire led       // 刺激活动指示（每周期点亮半周期）
);
    localparam integer CLK_HZ = 25_000_000;
    localparam integer PERIOD = CLK_HZ / 25;        // 25Hz  → 1_000_000 周期
    localparam integer PW     = CLK_HZ / 5000;      // 200µs → 5_000 周期
    localparam integer D      = CLK_HZ / 100_000;   // 10µs  → 250 周期

    localparam integer T1 = PW;                     // 正相结束
    localparam integer T2 = T1 + D;                 // 死区结束
    localparam integer T3 = T2 + PW;                // 负相结束

    reg [31:0] cnt;
    reg        act;

    // 上电初值（FPGA 配置后 FF 为 0；仿真需要显式初值，否则 X）
    initial begin
        cnt = 32'd0; in1 = 1'b0; in2 = 1'b0; act = 1'b0;
    end

    always @(posedge clk)
        cnt <= (cnt >= PERIOD - 1) ? 32'd0 : cnt + 32'd1;

    always @(posedge clk) begin
        if      (cnt < T1) begin in1 <= 1'b1; in2 <= 1'b0; end // 正相
        else if (cnt < T2) begin in1 <= 1'b0; in2 <= 1'b0; end // 死区(停, 安全中间态)
        else if (cnt < T3) begin in1 <= 1'b0; in2 <= 1'b1; end // 负相
        else               begin in1 <= 1'b0; in2 <= 1'b0; end // 停
    end

    // 刺激活动指示：每周期有一次脉冲 → 点亮半个周期，明显可见
    always @(posedge clk) begin
        if      (cnt == 32'd0)        act <= 1'b1;
        else if (cnt == PERIOD / 2)   act <= 1'b0;
    end
    assign led = act;
endmodule

`default_nettype wire
