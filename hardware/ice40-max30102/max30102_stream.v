// max30102_stream.v — 连续流固件：检测到新样本就发 FE E1 + RED 3 字节
//   目的：给 PC 端用【数样本时基】算准确 IBI（HRV），不丢样本、不重复
//   做法：轮询 FIFO_WR_PTR，一变就说明有新样本 → 对齐 RD_PTR=WR-1 → 读 1 个样本 → 发
//   MAX30102 用 HR-only 模式(0x02)：FIFO 3 字节/样本，100sps
//   UART 9600 8N1 | I2C SCL=ball46 SDA=ball44 | UART tx=ball6 | LED=ball39
`default_nettype none

module max30102_stream (
    output wire scl,
    inout  wire sda,
    output wire tx,
    output wire led
);
    // ---------- 12MHz ----------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));

    reg [15:0] rstc = 16'd0;
    wire rst = ~(&rstc);
    always @(posedge clk) if (rst) rstc <= rstc + 16'd1;

    reg [24:0] hb;
    always @(posedge clk) hb <= hb + 1'b1;
    assign led = ~hb[24];

    // ---------- I2C ----------
    reg        i2c_start, i2c_rw;
    reg [7:0]  i2c_reg, i2c_wdata, i2c_len;
    wire [7:0] i2c_rdata;
    wire       i2c_rvalid, i2c_done, i2c_busy;
    i2c_master #(.CLK_HZ(12_000_000), .SCL_HZ(100_000)) u_i2c (
        .clk(clk), .rst(rst), .start(i2c_start), .rw(i2c_rw), .dev(7'h57),
        .reg_addr(i2c_reg), .wr_data(i2c_wdata), .rd_len(i2c_len),
        .rd_data(i2c_rdata), .rd_valid(i2c_rvalid), .done(i2c_done),
        .ack_err(), .busy(i2c_busy), .scl(scl), .sda(sda)
    );

    // ---------- UART 115200 ----------
    reg [7:0] uart_data;
    reg       uart_send;
    wire      uart_busy;
    uart_tx #(.CLK_HZ(12_000_000), .BAUD(9600)) u_uart (
        .clk(clk), .data(uart_data), .send(uart_send), .tx(tx), .busy(uart_busy)
    );

    // ---------- 配置表（HR-only 模式）----------
    localparam NCFG = 8;
    reg [3:0] cfg_idx;
    reg [7:0] cfg_reg, cfg_dat;
    always @(*) begin
        case (cfg_idx)
            4'd0: begin cfg_reg = 8'h09; cfg_dat = 8'h40; end // RESET
            4'd1: begin cfg_reg = 8'h04; cfg_dat = 8'h00; end // FIFO_WR_PTR
            4'd2: begin cfg_reg = 8'h05; cfg_dat = 8'h00; end // OVF
            4'd3: begin cfg_reg = 8'h06; cfg_dat = 8'h00; end // FIFO_RD_PTR
            4'd4: begin cfg_reg = 8'h08; cfg_dat = 8'h10; end // 无平均 + rollover
            4'd5: begin cfg_reg = 8'h09; cfg_dat = 8'h02; end // MODE: HR-only (RED)
            4'd6: begin cfg_reg = 8'h0A; cfg_dat = 8'h27; end // 100sps / 411us
            4'd7: begin cfg_reg = 8'h0C; cfg_dat = 8'h12; end // LED1_PA (RED)
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

    localparam PWR_CY = 32'd240_000;  // 20ms
    localparam RST_CY = 32'd120_000;  // 10ms
    localparam CFG_CY = 32'd12_000;   // 1ms
    localparam POLL_CY= 32'd6_000;    // 0.5ms 轮询间隔

    reg [4:0]  state;
    reg [31:0] dly, dly_target;
    reg [7:0]  wr, last_wr;
    reg [2:0]  rx_idx;
    reg [7:0]  rxbuf [0:3];
    reg        rv_d;
    reg [2:0]  tx_idx;

    always @(posedge clk) begin
        uart_send <= 1'b0;
        rv_d <= i2c_rvalid;
        if (rst) begin
            state <= S_PWR; dly <= 0; dly_target <= PWR_CY;
            cfg_idx <= 0; rx_idx <= 0; wr <= 0; last_wr <= 8'hFF;
            i2c_start <= 0; i2c_rw <= 0; i2c_reg <= 0; i2c_wdata <= 0; i2c_len <= 0;
            tx_idx <= 0;
        end else begin
            case (state)
            // ---- 上电配置 ----
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

            // ---- 轮询 WR_PTR ----
            S_WR_SET: begin
                rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h04; i2c_len <= 8'd1;
                i2c_start <= 1; state <= S_WR_GO;
            end
            S_WR_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_WR_WAIT; end
            S_WR_WAIT: if (i2c_done) begin
                wr <= rxbuf[0];
                if (rxbuf[0] == last_wr) begin          // 没有新样本 → 等一会儿再轮询
                    dly <= 0; dly_target <= POLL_CY; state <= S_GAP;
                end else begin
                    state <= S_RDP_SET;                 // 有新样本 → 读它
                end
            end

            // ---- 对齐到最新样本 ----
            S_RDP_SET: begin
                i2c_rw <= 0; i2c_reg <= 8'h06;
                i2c_wdata <= (wr == 8'd0) ? 8'd31 : (wr - 8'd1);
                i2c_len <= 1; i2c_start <= 1; state <= S_RDP_GO;
            end
            S_RDP_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_RDP_WAIT; end
            S_RDP_WAIT: if (i2c_done) state <= S_FIFO_SET;

            // ---- 读 1 个样本（3 字节）----
            S_FIFO_SET: begin
                rx_idx <= 0;
                i2c_rw <= 1; i2c_reg <= 8'h07; i2c_len <= 8'd3;
                i2c_start <= 1; state <= S_FIFO_GO;
            end
            S_FIFO_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_FIFO_WAIT; end
            S_FIFO_WAIT: if (i2c_done) begin
                last_wr <= wr;
                tx_idx <= 0; state <= S_TX_SET;
            end

            // ---- 发 FE E1 R0 R1 R2 ----
            S_TX_SET: begin
                case (tx_idx)
                    3'd0: uart_data <= 8'hFE;
                    3'd1: uart_data <= 8'hE1;
                    3'd2: uart_data <= rxbuf[0] & 8'h03;
                    3'd3: uart_data <= rxbuf[1];
                    default: uart_data <= rxbuf[2];
                endcase
                uart_send <= 1'b1; state <= S_TX_GO;
            end
            S_TX_GO: begin uart_send <= 1'b0; if (uart_busy) state <= S_TX_WAIT; end
            S_TX_WAIT: if (!uart_busy) begin
                if (tx_idx == 3'd4) begin dly <= 0; dly_target <= POLL_CY; state <= S_GAP; end
                else begin tx_idx <= tx_idx + 3'd1; state <= S_TX_SET; end
            end

            S_GAP: if (dly >= dly_target) begin dly <= 0; state <= S_WR_SET; end
                   else dly <= dly + 1'b1;
            default: state <= S_PWR;
            endcase

            // 读回字节捕获
            if (i2c_rvalid && !rv_d && rx_idx < 3'd3) begin
                rxbuf[rx_idx] <= i2c_rdata;
                rx_idx       <= rx_idx + 3'd1;
            end
        end
    end
endmodule

`default_nettype wire
