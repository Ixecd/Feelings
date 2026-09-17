// ecp5_stim_pulse.v — tVNS 双相脉冲发生器（Colorlight i5 / ECP5-25F）
//   输出 EN/IN1/IN2 → (ISO7721 隔离) → L293D H桥 → 恒流源 → 电极
//   双相: 正相 → 死区(EN=0, 极性在 EN=0 时切换) → 负相 → 停
//   参数: 频率 25Hz, 脉宽 200µs/相, 死区 2×10µs
//   ★ 安全: 极性只在 EN=0 时切换(防 H 桥直通); 无 DAC 时电流由 LM334 电位器定(手动版)
//   时钟 25MHz (i5 P3) | LED=U16 刺激活动指示
`default_nettype none

module ecp5_stim_pulse (
    input  wire clk,      // 25MHz (P3)
    output reg  en,       // → L293D EN1（经隔离）
    output reg  in1,      // → L293D IN1
    output reg  in2,      // → L293D IN2
    output wire led       // 刺激活动指示（每周期点亮半周期）
);
    localparam integer CLK_HZ = 25_000_000;
    localparam integer PERIOD = CLK_HZ / 25;        // 25Hz  → 1_000_000 周期
    localparam integer PW     = CLK_HZ / 5000;      // 200µs → 5_000 周期
    localparam integer D      = CLK_HZ / 100_000;   // 10µs  → 250 周期

    // 周期内时序边界
    localparam integer T1 = PW;                     // 正相结束
    localparam integer T2 = T1 + D;                 // g1 结束（EN 已落）
    localparam integer T3 = T2 + D;                 // s1 结束（极性切到负相，EN 仍 0）
    localparam integer T4 = T3 + PW;                // 负相结束
    localparam integer T5 = T4 + D;                 // g2 结束
    localparam integer T6 = T5 + D;                 // s2 结束（极性归零）

    reg [31:0] cnt;
    reg        act;

    // 上电初值（FPGA 配置后 FF 为 0；仿真需要显式初值，否则 X）
    initial begin
        cnt = 32'd0; en = 1'b0; in1 = 1'b0; in2 = 1'b0; act = 1'b0;
    end

    always @(posedge clk)
        cnt <= (cnt >= PERIOD - 1) ? 32'd0 : cnt + 32'd1;

    always @(posedge clk) begin
        if      (cnt < T1) begin en <= 1'b1; in1 <= 1'b1; in2 <= 1'b0; end // 正相
        else if (cnt < T2) begin en <= 1'b0; in1 <= 1'b1; in2 <= 1'b0; end // g1: EN 落
        else if (cnt < T3) begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b1; end // s1: 切极性(EN=0)
        else if (cnt < T4) begin en <= 1'b1; in1 <= 1'b0; in2 <= 1'b1; end // 负相
        else if (cnt < T5) begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b1; end // g2: EN 落
        else if (cnt < T6) begin en <= 1'b0; in1 <= 1'b0; in2 <= 1'b0; end // s2: 归零
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
