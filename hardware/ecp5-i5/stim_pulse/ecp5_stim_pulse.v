// ecp5_stim_pulse.v — tVNS 双相脉冲发生器（Colorlight i5 / ECP5-25F）
//   输出 EN/IN1/IN2 → (2× ISO7721 隔离, 共 3 路) → L293D H桥 → 恒流源 → 电极
//   ★ 3 线方案: EN 由本模块引出(不再硬接 VCC) —— 贴人侧 EN1 = EN(隔离后) AND 比较器_safe
//     · 正常脉冲: EN=1 且 (IN1,IN2)=(1,0)正相 / (0,1)负相
//     · 死区/停: EN=0 且 (IN1,IN2)=(0,0) —— 双重安全
//     · 硬件安全比较器可独立把 EN1 拉低 → 不经 FPGA 硬关 H 桥
//   参数: 频率 25Hz, 脉宽 200µs/相, 死区 10µs
//   时钟 25MHz (i5 P3) | LED=U16 刺激活动指示
//   ★ EN 默认低（复位/配置后为 0）→ 上电即安全态
`default_nettype none

module ecp5_stim_pulse (
    input  wire clk,      // 25MHz (P3)
    output reg  en,       // → L293D EN1（经隔离；贴人侧与比较器 safe 相与）默认低
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
    // ★ EN 初值 0 → 上电即安全态
    initial begin
        cnt = 32'd0; en = 1'b0; in1 = 1'b0; in2 = 1'b0; act = 1'b0;
    end

    always @(posedge clk)
        cnt <= (cnt >= PERIOD - 1) ? 32'd0 : cnt + 32'd1;

    // EN 与 IN1/IN2 同拍寄存：脉冲相 EN=1，死区/停 EN=0
    always @(posedge clk) begin
        if      (cnt < T1) begin en <= 1'b1; in1 <= 1'b1; in2 <= 1'b0; end // 正相
        else if (cnt < T2) begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b0; end // 死区(停, 安全中间态)
        else if (cnt < T3) begin en <= 1'b1; in1 <= 1'b0; in2 <= 1'b1; end // 负相
        else               begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b0; end // 停
    end

    // 刺激活动指示：每周期有一次脉冲 → 点亮半个周期，明显可见
    always @(posedge clk) begin
        if      (cnt == 32'd0)        act <= 1'b1;
        else if (cnt == PERIOD / 2)   act <= 1'b0;
    end
    assign led = act;
endmodule

`default_nettype wire
