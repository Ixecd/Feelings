// tb_stim.v — 验证 ecp5_stim_pulse：双相波形 / 脉宽 / 死区 / 极性安全切换 / EN 门控
`timescale 1ns/1ps
`default_nettype none

module tb_stim;
    reg clk = 0;
    always #20 clk = ~clk;                 // 25MHz (周期 40ns)
    wire en, in1, in2, led;
    ecp5_stim_pulse dut (.clk(clk), .en(en), .in1(in1), .in2(in2), .led(led));

    integer errs = 0;
    reg p_in1 = 0, p_in2 = 0;

    // 不变量检查（每个时钟沿）
    always @(posedge clk) begin
        // 1) 极性切换必须经过 (0,0) 中间态（不能直接从 (1,0) 跳到 (0,1)）
        if (p_in1 === 1'b1 && p_in2 === 1'b0 && in1 === 1'b0 && in2 === 1'b1) begin
            $display("  **FAIL** 极性直跳 (1,0)->(0,1) 未过中间态 @%0t", $time);
            errs = errs + 1;
        end
        if (p_in1 === 1'b0 && p_in2 === 1'b1 && in1 === 1'b1 && in2 === 1'b0) begin
            $display("  **FAIL** 极性直跳 (0,1)->(1,0) 未过中间态 @%0t", $time);
            errs = errs + 1;
        end
        // 2) EN 门控：EN=1 时必须有方向（不能是 (0,0) 空档）
        if (en === 1'b1 && in1 === 1'b0 && in2 === 1'b0) begin
            $display("  **FAIL** EN=1 但 IN1/IN2=(0,0) 无方向 @%0t", $time);
            errs = errs + 1;
        end
        // 3) EN 门控：死区/停 (0,0) 时 EN 必须为 0（双重关断）
        if (in1 === 1'b0 && in2 === 1'b0 && en === 1'b1) begin
            $display("  **FAIL** (0,0) 死区但 EN=1 未关断 @%0t", $time);
            errs = errs + 1;
        end
        p_in1 <= in1; p_in2 <= in2;
    end

    // 打印每次变化，便于人工核对波形
    reg q_en = 0, q_in1 = 0, q_in2 = 0;
    always @(posedge clk) begin
        if (en !== q_en || in1 !== q_in1 || in2 !== q_in2)
            $display("  t=%0t  en=%b in1=%b in2=%b", $time, en, in1, in2);
        q_en <= en; q_in1 <= in1; q_in2 <= in2;
    end

    initial begin
        $timeformat(-9, 3, " ns", 0);       // %t 按 ns 显示
        $display("=== ECP5 刺激脉冲波形仿真（3线 EN+IN1/IN2, 25Hz, 200µs/相, 死区10µs）===");
        // 上电初值应为安全态
        #1 if (en !== 1'b0) begin $display("  **FAIL** 上电 EN 非 0 @%0t", $time); errs = errs + 1; end
        #90_000_000;                        // 90ms ≈ 2.25 周期（周期 40ms）
        $display("=== 结束, errs=%0d ===", errs);
        $finish;
    end
endmodule

`default_nettype wire
