// hr_estimator.v — 从 PPG 原始 RED 估计心率（定点/整数，无浮点）
//   带通(高通去DC + 低通去噪) → 3点局部极大 + 迟滞阈值(75%/25%) + 不应期
//   → IBI 离群抑制 + IIR 平滑 → BPM = 60000/IBI_avg
`default_nettype none

module hr_estimator #(
    parameter CLK_HZ = 12_000_000,
    parameter REFRACT_MS = 300
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_valid,
    input  wire [17:0] sample,
    output reg  [7:0]  bpm,
    output reg         beat,
    output reg  [15:0] ibi_out,
    output reg  [2:0]  quality
);
    localparam TICK_DIV = CLK_HZ / 1000;

    // ---------- 1ms 时基 ----------
    reg [15:0] tc;
    wire ms_tick = (tc == TICK_DIV - 1);
    always @(posedge clk)
        if (rst) tc <= 16'd0;
        else     tc <= ms_tick ? 16'd0 : tc + 16'd1;

    // ---------- 高通去 DC（>>>5 ≈ 0.5Hz @100sps；首样本直接对齐避免瞬态）----------
    reg signed [23:0] dc, ac;
    reg started;
    wire signed [23:0] xs = $signed({6'b0, sample});
    always @(posedge clk) begin
        if (rst) begin dc <= 24'sd0; ac <= 24'sd0; started <= 1'b0; end
        else if (sample_valid) begin
            if (!started) begin started <= 1'b1; dc <= xs; ac <= 24'sd0; end
            else begin ac <= xs - dc; dc <= dc + ((xs - dc) >>> 5); end   // 高通 ~0.5Hz @100sps
        end
    end

    // ---------- 低通（>>>2 ≈ 4Hz @100sps）→ 0.5~4Hz 带通 ----------
    reg signed [23:0] sm;
    always @(posedge clk)
        if (rst) sm <= 24'sd0;
        else if (sample_valid) sm <= sm + ((ac - sm) >>> 2);   // 低通 ~4Hz @100sps

    // ---------- 3 点延迟线 ----------
    reg signed [23:0] d0, d1, d2;
    always @(posedge clk) if (sample_valid) begin d0 <= sm; d1 <= d0; d2 <= d1; end

    // ---------- 幅度包络 ----------
    reg signed [23:0] emax, emin;
    always @(posedge clk) begin
        if (rst) begin emax <= 24'sd0; emin <= 24'sd0; end
        else if (sample_valid) begin
            if (sm > emax) emax <= sm; else emax <= emax - (emax >>> 7);
            if (sm < emin) emin <= sm; else emin <= emin + ((0 - emin) >>> 7);
        end
    end
    wire signed [23:0] range  = emax - emin;
    wire signed [23:0] thr_hi = emin + (range - (range >>> 2));   // 75%
    wire signed [23:0] thr_lo = emin + (range >>> 2);             // 25%

    // ---------- 不应期 ----------
    reg [15:0] ms_since_beat;
    always @(posedge clk) begin
        if (rst) ms_since_beat <= 16'd0;
        else if (beat) ms_since_beat <= 16'd0;
        else if (ms_tick) ms_since_beat <= ms_since_beat + 16'd1;
    end

    // ---------- 峰检测（迟滞）----------
    wire local_max = (d1 > d0) && (d1 > d2);
    wire refr_ok   = (ms_since_beat > REFRACT_MS);
    reg  armed;

    // ---------- IBI 平滑 + 离群抑制 ----------
    reg [15:0] ibi_avg;
    reg        have_ibi;
    reg [9:0]  good_cnt;
    wire [15:0] ibi_diff = (ms_since_beat > ibi_avg) ? (ms_since_beat - ibi_avg)
                                                      : (ibi_avg - ms_since_beat);
    wire        ibi_ok   = !have_ibi || (ibi_diff < (ibi_avg >> 2));

    // ---------- BPM = 60000 / ibi_avg（迭代减法，一次/心跳）----------
    reg [15:0] q;
    reg [16:0] rem, dv;
    reg        div_run, div_start;

    always @(posedge clk) begin
        beat      <= 1'b0;
        div_start <= 1'b0;
        if (rst) begin
            armed <= 1'b1; ibi_avg <= 16'd0; have_ibi <= 1'b0; good_cnt <= 10'd0;
            bpm <= 8'd0; ibi_out <= 16'd0; quality <= 3'd0;
            div_run <= 1'b0; q <= 16'd0; rem <= 17'd0; dv <= 17'd0;
        end else begin
            if (sample_valid) begin
                if (!armed) begin
                    if (d1 < thr_lo) armed <= 1'b1;          // 落回低位才重新武装
                end else if (local_max && (d1 > thr_hi) && refr_ok) begin
                    armed    <= 1'b0;
                    beat     <= 1'b1;
                    ibi_out  <= ms_since_beat;
                    if (ms_since_beat < 16'd2000 && ibi_ok) begin
                        if (!have_ibi) begin ibi_avg <= ms_since_beat; have_ibi <= 1'b1; end
                        else           ibi_avg <= (ibi_avg * 3 + ms_since_beat) >> 2;
                        div_start <= 1'b1;
                        if (good_cnt < 10'd255) good_cnt <= good_cnt + 10'd1;
                    end
                end
            end

            if (div_start) begin
                rem <= 17'd60000; dv <= {1'b0, ibi_avg}; q <= 16'd0; div_run <= 1'b1;
            end else if (div_run) begin
                if (rem >= dv) begin rem <= rem - dv; q <= q + 16'd1; end
                else begin
                    div_run <= 1'b0;
                    if (q >= 16'd30 && q <= 16'd220) bpm <= q[7:0];
                end
            end

            quality <= (good_cnt >= 10'd5) ? 3'd7 : good_cnt[2:0];
        end
    end
endmodule

`default_nettype wire
