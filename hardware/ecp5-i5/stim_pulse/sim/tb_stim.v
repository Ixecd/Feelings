// tb_stim.v — 验证 ecp5_stim_pulse：双相波形 / 脉宽 / 死区 / 极性安全切换
`timescale 1ns/1ps
`default_nettype none

module tb_stim;
    reg clk = 0;
    always #20 clk = ~clk;                 // 25MHz (周期 40ns)
    wire in1, in2, led;
    ecp5_stim_pulse dut (.clk(clk), .in1(in1), .in2(in2), .led(led));

    integer errs = 0;
    reg p_in1 = 0, p_in2 = 0;

    always @(posedge clk) begin
        if (in1 !== p_in1 || in2 !== p_in2) begin
            $display("  t=%0t  in1=%b in2=%b", $time, in1, in2);
            // 不变量: 极性切换必须经过 (0,0) 中间态（不能直接从 (1,0) 跳到 (0,1)）
            if (p_in1 === 1'b1 && p_in2 === 1'b0 && in1 === 1'b0 && in2 === 1'b1) begin
                $display("  **FAIL** 极性直跳 (1,0)->(0,1) 未过中间态 @%0t", $time);
                errs = errs + 1;
            end
            if (p_in1 === 1'b0 && p_in2 === 1'b1 && in1 === 1'b1 && in2 === 1'b0) begin
                $display("  **FAIL** 极性直跳 (0,1)->(1,0) 未过中间态 @%0t", $time);
                errs = errs + 1;
            end
            p_in1 <= in1; p_in2 <= in2;
        end
    end

    initial begin
        $timeformat(-9, 3, " ns", 0);       // %t 按 ns 显示
        $display("=== ECP5 刺激脉冲波形仿真（2线, 25Hz, 200µs/相）===");
        #90_000_000;                        // 90ms ≈ 2.25 周期（周期 40ms）
        $display("=== 结束, errs=%0d ===", errs);
        $finish;
    end
endmodule

`default_nettype wire
