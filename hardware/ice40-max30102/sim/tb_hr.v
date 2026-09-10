// tb_hr.v — 合成 PPG(正弦 + 0.3Hz 运动伪迹 + 噪声) 验证 hr_estimator
`timescale 1ns/1ps
`default_nettype none

module tb_hr;
    reg        clk = 0, rst = 1;
    reg        sv = 0;
    reg [17:0] samp = 0;
    wire [7:0]  bpm;
    wire        beat;
    wire [15:0] ibi;
    wire [2:0]  q;

    // 仿真用 CLK_HZ=24000 → 1ms=24clk, 1s=24000clk, 采样 100Hz=240clk
    hr_estimator #(.CLK_HZ(24000), .REFRACT_MS(300)) dut (
        .clk(clk), .rst(rst), .sample_valid(sv), .sample(samp),
        .bpm(bpm), .beat(beat), .ibi_out(ibi), .quality(q)
    );

    always #1 clk = ~clk;

    integer scnt = 0;
    integer cnt  = 0;
    real    tt, val, freq;
    integer hr = 72;

    initial begin
        freq = hr / 60.0;
        #40 rst = 0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cnt <= cnt + 1;
            if (cnt == 239) begin
                cnt <= 0;
                tt  = scnt / 100.0;
                val = 100000.0
                    + 3000.0 * $sin(2.0*3.14159265*freq*tt)          // 脉搏
                    + 1500.0 * $sin(2.0*3.14159265*0.30*tt)          // 运动伪迹 0.3Hz
                    + 400.0  * $random/2147483648.0;                  // 噪声
                samp <= val;
                sv   <= 1'b1;
                scnt <= scnt + 1;
            end else sv <= 1'b0;
        end
    end

    integer beats = 0;
    always @(posedge clk) if (beat) begin
        beats <= beats + 1;
        $display("  BEAT #%0d @%.2fs ibi=%0dms", beats+1, scnt/100.0, ibi);
    end

    initial begin
        #(20*24000*2);   // 20 秒
        $display("=== 目标 %0d BPM, 最终 bpm=%0d (共 %0d 拍) ===", hr, bpm, beats);
        if (bpm >= hr-5 && bpm <= hr+5) $display(">>> PASS");
        else $display(">>> FAIL");
        $finish;
    end
endmodule

`default_nettype wire
