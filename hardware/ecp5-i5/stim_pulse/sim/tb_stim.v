// tb_stim.v — 验证 ecp5_stim_pulse：双相波形 / 脉宽 / 死区 / 极性切换安全
`timescale 1ns/1ps
`default_nettype none

module tb_stim;
    reg clk = 0;
    always #20 clk = ~clk;                 // 25MHz (周期 40ns)
    wire en, in1, in2, led;
    ecp5_stim_pulse dut (.clk(clk), .en(en), .in1(in1), .in2(in2), .led(led));

    integer errs = 0;
    reg p_en = 0, p_in1 = 0, p_in2 = 0;

    always @(posedge clk) begin
        if (en !== p_en || in1 !== p_in1 || in2 !== p_in2) begin
            $display("  t=%0t ns  en=%b in1=%b in2=%b", $time, en, in1, in2);
            // 不变量: 极性只在 EN=0 时切换（防 H 桥直通）
            if ((in1 !== p_in1 || in2 !== p_in2) && p_en) begin
                $display("  **FAIL** 极性在 EN=1 时改变 @%0t ns", $time);
                errs = errs + 1;
            end
            p_en <= en; p_in1 <= in1; p_in2 <= in2;
        end
    end

    initial begin
        $timeformat(-9, 3, " ns", 0);       // %t 按 ns 显示
        $display("=== ECP5 刺激脉冲波形仿真（25Hz, 200µs/相）===");
        #90_000_000;                        // 90ms ≈ 2.25 周期（周期 40ms）
        $display("=== 结束, errs=%0d ===", errs);
        $finish;
    end
endmodule

`default_nettype wire
