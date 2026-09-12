// max30102_ppg.v — 顶层：上电配置 MAX30102，周期读 FIFO 原始值，UART 输出
//   上电: 等 20ms → 写配置寄存器序列
//   循环: 读 FIFO_WR_PTR(0x04) → 写 FIFO_RD_PTR(0x06)=WR-1 (对齐到最新完整样本)
//         → 读 FIFO_DATA(0x07) 6 字节 → UART 发 FE E1 + 6 字节 → 等 ~30ms
//   UART: 9600 8N1, tx=ball6 | I2C: SCL=ball46, SDA=ball44 | LED=ball39 心跳
`default_nettype none

module max30102_ppg (
    output wire scl,
    inout  wire sda,
    output wire tx,
    output wire led
);
    // ---------- 内部 24MHz 振荡器（48MHz 时序不收敛，降到 24MHz）----------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b01")) osc (
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
    reg        i2c_start;
    reg        i2c_rw;
    reg [7:0]  i2c_reg, i2c_wdata, i2c_len;
    wire [7:0] i2c_rdata;
    wire       i2c_rvalid, i2c_done, i2c_busy, i2c_ackerr;

    i2c_master #(.CLK_HZ(24_000_000), .SCL_HZ(100_000)) u_i2c (
        .clk(clk), .rst(rst), .start(i2c_start), .rw(i2c_rw), .dev(7'h57),
        .reg_addr(i2c_reg), .wr_data(i2c_wdata), .rd_len(i2c_len),
        .rd_data(i2c_rdata), .rd_valid(i2c_rvalid), .done(i2c_done),
        .ack_err(i2c_ackerr), .busy(i2c_busy), .scl(scl), .sda(sda)
    );

    // ---------- UART ----------
    reg [7:0] uart_data;
    reg       uart_send;
    wire      uart_busy;
    uart_tx #(.CLK_HZ(24_000_000), .BAUD(9600)) u_uart (
        .clk(clk), .data(uart_data), .send(uart_send), .tx(tx), .busy(uart_busy)
    );

    // ---------- 配置表 ----------
    localparam NCFG = 9;
    reg [3:0] cfg_idx;
    reg [7:0] cfg_reg, cfg_dat;
    always @(*) begin
        case (cfg_idx)
            4'd0: begin cfg_reg = 8'h09; cfg_dat = 8'h40; end // MODE: RESET
            4'd1: begin cfg_reg = 8'h04; cfg_dat = 8'h00; end // FIFO_WR_PTR
            4'd2: begin cfg_reg = 8'h05; cfg_dat = 8'h00; end // OVF_COUNTER
            4'd3: begin cfg_reg = 8'h06; cfg_dat = 8'h00; end // FIFO_RD_PTR
            4'd4: begin cfg_reg = 8'h08; cfg_dat = 8'h10; end // FIFO_CONFIG: 无平均, rollover
            4'd5: begin cfg_reg = 8'h09; cfg_dat = 8'h03; end // MODE: SpO2 (RED+IR)
            4'd6: begin cfg_reg = 8'h0A; cfg_dat = 8'h27; end // SPO2: 4096nA,100sps,411us
            4'd7: begin cfg_reg = 8'h0C; cfg_dat = 8'h24; end // LED1_PA (RED) 7.2mA
            4'd8: begin cfg_reg = 8'h0D; cfg_dat = 8'h12; end // LED2_PA (IR)  7.2mA
            default: begin cfg_reg = 8'h00; cfg_dat = 8'h00; end
        endcase
    end

    // ---------- 主状态机 ----------
    localparam
        S_PWR = 5'd0, S_CFG_SET = 5'd1, S_CFG_GO = 5'd2, S_CFG_WAIT = 5'd3, S_DELAY = 5'd4,
        S_WR_SET = 5'd5, S_WR_GO = 5'd6, S_WR_WAIT = 5'd7,
        S_RDP_SET = 5'd8, S_RDP_GO = 5'd9, S_RDP_WAIT = 5'd10,
        S_FIFO_SET = 5'd11, S_FIFO_GO = 5'd12, S_FIFO_WAIT = 5'd13,
        S_TX_SET = 5'd14, S_TX_GO = 5'd15, S_TX_WAIT = 5'd16, S_GAP = 5'd17;

    localparam PWR_CY  = 32'd480_000;    // 20ms @24MHz
    localparam RST_CY  = 32'd240_000;    // 10ms (RESET 后)
    localparam CFG_CY  = 32'd24_000;     // 1ms  (配置间隙)
    localparam GAP_CY  = 32'd600_000;    // ~25ms (读周期)

    reg [4:0]  state;
    reg [31:0] dly, dly_target;
    reg [2:0]  tx_idx;
    reg [2:0]  rx_idx;
    reg [7:0]  rxbuf [0:5];
    reg [7:0]  wr_ptr;

    reg rv_d;
    always @(posedge clk) begin
        uart_send <= 1'b0;
        rv_d      <= i2c_rvalid;
        if (rst) begin
            state <= S_PWR; dly <= 0; dly_target <= PWR_CY;
            cfg_idx <= 0; tx_idx <= 0; rx_idx <= 0; wr_ptr <= 0;
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

            // ---- 读 FIFO_WR_PTR ----
            S_WR_SET: begin
                rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h04; i2c_len <= 8'd1;
                i2c_start <= 1; state <= S_WR_GO;
            end
            S_WR_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_WR_WAIT; end
            S_WR_WAIT: if (i2c_done) begin
                wr_ptr <= rxbuf[0];
                state  <= S_RDP_SET;
            end

            // ---- 写 FIFO_RD_PTR = WR-1（对齐到最新完整样本）----
            S_RDP_SET: begin
                i2c_rw <= 0; i2c_reg <= 8'h06;
                i2c_wdata <= (wr_ptr == 8'd0) ? 8'd31 : (wr_ptr - 8'd1);
                i2c_len <= 1; i2c_start <= 1; state <= S_RDP_GO;
            end
            S_RDP_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_RDP_WAIT; end
            S_RDP_WAIT: if (i2c_done) state <= S_FIFO_SET;

            // ---- 读 FIFO_DATA 6 字节 ----
            S_FIFO_SET: begin
                rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h07; i2c_len <= 8'd6;
                i2c_start <= 1; state <= S_FIFO_GO;
            end
            S_FIFO_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_FIFO_WAIT; end
            S_FIFO_WAIT: if (i2c_done) begin tx_idx <= 0; state <= S_TX_SET; end

            // ---- UART 发送: FE E1 + 6 字节 (每通道首字节屏蔽到 18 位) ----
            S_TX_SET: begin
                if      (tx_idx == 3'd0) uart_data <= 8'hFE;
                else if (tx_idx == 3'd1) uart_data <= 8'hE1;
                else if (tx_idx == 3'd2 || tx_idx == 3'd5)
                    uart_data <= rxbuf[tx_idx - 3'd2] & 8'h03;   // 屏蔽首字节高 6 位
                else
                    uart_data <= rxbuf[tx_idx - 3'd2];
                uart_send <= 1'b1; state <= S_TX_GO;
            end
            S_TX_GO: begin
                uart_send <= 1'b0;
                if (uart_busy) state <= S_TX_WAIT;
            end
            S_TX_WAIT: if (!uart_busy) begin
                if (tx_idx == 3'd7) begin dly <= 0; dly_target <= GAP_CY; state <= S_GAP; end
                else begin tx_idx <= tx_idx + 3'd1; state <= S_TX_SET; end
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
endmodule

`default_nettype wire
