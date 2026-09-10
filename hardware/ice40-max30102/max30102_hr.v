// max30102_hr.v — 板上实时心率：配置 MAX30102 → ~100sps 读 FIFO → hr_estimator → UART 输出
//   每检测到一次心跳，往串口发一行 "HR=NN\r\n"（ASCII，直接可读）
//   UART: 9600 8N1, tx=ball6 | I2C: SCL=ball46, SDA=ball44 | LED=ball39 心跳
`default_nettype none

module max30102_hr (
    output wire scl,
    inout  wire sda,
    output wire tx,
    output wire led
);
    // ---------- 内部 24MHz 振荡器 ----------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    // ---------- 上电复位 ----------
    reg [15:0] rstc = 16'd0;
    wire rst = ~(&rstc);
    always @(posedge clk) if (rst) rstc <= rstc + 16'd1;

    // ---------- LED 心跳 ----------
    reg [24:0] hb;
    always @(posedge clk) hb <= hb + 1'b1;
    assign led = ~hb[24];

    // ---------- I2C master ----------
    reg        i2c_start, i2c_rw;
    reg [7:0]  i2c_reg, i2c_wdata, i2c_len;
    wire [7:0] i2c_rdata;
    wire       i2c_rvalid, i2c_done, i2c_busy, i2c_ackerr;
    i2c_master #(.CLK_HZ(12_000_000), .SCL_HZ(100_000)) u_i2c (
        .clk(clk), .rst(rst), .start(i2c_start), .rw(i2c_rw), .dev(7'h57),
        .reg_addr(i2c_reg), .wr_data(i2c_wdata), .rd_len(i2c_len),
        .rd_data(i2c_rdata), .rd_valid(i2c_rvalid), .done(i2c_done),
        .ack_err(i2c_ackerr), .busy(i2c_busy), .scl(scl), .sda(sda)
    );

    // ---------- UART ----------
    reg [7:0] uart_data;
    reg       uart_send;
    wire      uart_busy;
    uart_tx #(.CLK_HZ(12_000_000), .BAUD(9600)) u_uart (
        .clk(clk), .data(uart_data), .send(uart_send), .tx(tx), .busy(uart_busy)
    );

    // ---------- 配置表 ----------
    localparam NCFG = 9;
    reg [3:0] cfg_idx;
    reg [7:0] cfg_reg, cfg_dat;
    always @(*) begin
        case (cfg_idx)
            4'd0: begin cfg_reg = 8'h09; cfg_dat = 8'h40; end // RESET
            4'd1: begin cfg_reg = 8'h04; cfg_dat = 8'h00; end
            4'd2: begin cfg_reg = 8'h05; cfg_dat = 8'h00; end
            4'd3: begin cfg_reg = 8'h06; cfg_dat = 8'h00; end
            4'd4: begin cfg_reg = 8'h08; cfg_dat = 8'h10; end // 无平均 + rollover
            4'd5: begin cfg_reg = 8'h09; cfg_dat = 8'h03; end // SpO2
            4'd6: begin cfg_reg = 8'h0A; cfg_dat = 8'h27; end // 100sps/411us
            4'd7: begin cfg_reg = 8'h0C; cfg_dat = 8'h24; end
            4'd8: begin cfg_reg = 8'h0D; cfg_dat = 8'h24; end
            default: begin cfg_reg = 8'h00; cfg_dat = 8'h00; end
        endcase
    end

    // ---------- 读回字节 & RED ----------
    reg [2:0]  rx_idx;
    reg [7:0]  rxbuf [0:5];
    reg [7:0]  wr_ptr;
    wire [17:0] red = {rxbuf[0][1:0], rxbuf[1], rxbuf[2]};

    // ---------- 心率估计器 ----------
    reg         sample_pulse;
    wire [7:0]  hr_bpm;
    wire        hr_beat;
    wire [15:0] hr_ibi;
    wire [2:0]  hr_q;
    hr_estimator #(.CLK_HZ(12_000_000), .REFRACT_MS(300)) u_hr (
        .clk(clk), .rst(rst), .sample_valid(sample_pulse), .sample(red),
        .bpm(hr_bpm), .beat(hr_beat), .ibi_out(hr_ibi), .quality(hr_q)
    );

    // ---------- 主状态机 ----------
    localparam
        S_PWR = 4'd0, S_CFG_SET = 4'd1, S_CFG_GO = 4'd2, S_CFG_WAIT = 4'd3, S_DELAY = 4'd4,
        S_WR_SET = 4'd5, S_WR_GO = 4'd6, S_WR_WAIT = 4'd7,
        S_RDP_SET = 4'd8, S_RDP_GO = 4'd9, S_RDP_WAIT = 4'd10,
        S_FIFO_SET = 4'd11, S_FIFO_GO = 4'd12, S_FIFO_WAIT = 4'd13, S_GAP = 4'd14;

    localparam PWR_CY = 32'd480_000;   // 20ms
    localparam RST_CY = 32'd240_000;   // 10ms
    localparam CFG_CY = 32'd24_000;    // 1ms
    localparam GAP_CY = 32'd101_000;   // ~8.4ms (+事务~1.6ms → 周期≈10ms → ~100sps)

    reg [3:0]  state;
    reg [31:0] dly, dly_target;
    reg        rv_d;

    always @(posedge clk) begin
        sample_pulse <= 1'b0;
        rv_d <= i2c_rvalid;
        if (rst) begin
            state <= S_PWR; dly <= 0; dly_target <= PWR_CY;
            cfg_idx <= 0; rx_idx <= 0; wr_ptr <= 0;
            i2c_start <= 0; i2c_rw <= 0; i2c_reg <= 0; i2c_wdata <= 0; i2c_len <= 0;
        end else begin
            case (state)
            S_PWR: if (dly >= dly_target) begin dly <= 0; state <= S_CFG_SET; end
                   else dly <= dly + 1'b1;
            S_CFG_SET: begin
                i2c_rw <= 0; i2c_reg <= cfg_reg; i2c_wdata <= cfg_dat; i2c_len <= 1;
                i2c_start <= 1; state <= S_CFG_GO;
            end
            S_CFG_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_CFG_WAIT; end
            S_CFG_WAIT: if (i2c_done) begin
                if (cfg_idx == 4'd0) dly_target <= RST_CY; else dly_target <= CFG_CY;
                dly <= 0; state <= S_DELAY;
            end
            S_DELAY: if (dly >= dly_target) begin
                dly <= 0;
                if (cfg_idx == NCFG-1) state <= S_WR_SET;
                else begin cfg_idx <= cfg_idx + 4'd1; state <= S_CFG_SET; end
            end else dly <= dly + 1'b1;

            S_WR_SET: begin
                rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h04; i2c_len <= 8'd1;
                i2c_start <= 1; state <= S_WR_GO;
            end
            S_WR_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_WR_WAIT; end
            S_WR_WAIT: if (i2c_done) begin wr_ptr <= rxbuf[0]; state <= S_RDP_SET; end

            S_RDP_SET: begin
                i2c_rw <= 0; i2c_reg <= 8'h06;
                i2c_wdata <= (wr_ptr == 8'd0) ? 8'd31 : (wr_ptr - 8'd1);
                i2c_len <= 1; i2c_start <= 1; state <= S_RDP_GO;
            end
            S_RDP_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_RDP_WAIT; end
            S_RDP_WAIT: if (i2c_done) state <= S_FIFO_SET;

            S_FIFO_SET: begin rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h07; i2c_len <= 8'd6;
                i2c_start <= 1; state <= S_FIFO_GO;
            end
            S_FIFO_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_FIFO_WAIT; end
            S_FIFO_WAIT: if (i2c_done) begin
                sample_pulse <= 1'b1;         // 把这一样本喂给心率估计器
                dly <= 0; dly_target <= GAP_CY; state <= S_GAP;
            end

            S_GAP: if (dly >= dly_target) begin dly <= 0; state <= S_WR_SET; end
                   else dly <= dly + 1'b1;
            default: state <= S_PWR;
            endcase

            // 读回字节捕获
            if (i2c_rvalid && !rv_d && rx_idx < 3'd6) begin
                rxbuf[rx_idx] <= i2c_rdata;
                rx_idx       <= rx_idx + 3'd1;
            end
        end
    end

    // ---------- 心跳时发一行 "HR=NN\r\n" ----------
    localparam
        T_IDLE = 2'd0, T_LOAD = 2'd1, T_WAIT1 = 2'd2, T_WAIT0 = 2'd3;
    reg [1:0] tst;
    reg [2:0] mi;
    reg [7:0] msg [0:7];

    always @(posedge clk) begin
        uart_send <= 1'b0;
        if (rst) begin
            tst <= T_IDLE; mi <= 0;
        end else begin
            case (tst)
            T_IDLE: if (hr_beat) begin
                msg[0] <= "H"; msg[1] <= "R"; msg[2] <= "=";
                msg[3] <= 8'h30 + (hr_bpm / 8'd100);
                msg[4] <= 8'h30 + ((hr_bpm / 8'd10) % 8'd10);
                msg[5] <= 8'h30 + (hr_bpm % 8'd10);
                msg[6] <= 8'h0D; msg[7] <= 8'h0A;
                mi <= 0; tst <= T_LOAD;
            end
            T_LOAD: begin uart_data <= msg[mi]; uart_send <= 1'b1; tst <= T_WAIT1; end
            T_WAIT1: begin uart_send <= 1'b0; if (uart_busy) tst <= T_WAIT0; end
            T_WAIT0: if (!uart_busy) begin
                if (mi == 3'd7) tst <= T_IDLE;
                else begin mi <= mi + 3'd1; tst <= T_LOAD; end
            end
            endcase
        end
    end
endmodule

`default_nettype wire
