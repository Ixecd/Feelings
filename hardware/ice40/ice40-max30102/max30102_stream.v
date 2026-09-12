// max30102_stream.v — 连续流固件 v2：PPG(RED) + MPU6050 加速度
//   PPG : FE E1 + RED 3 字节（HR-only 模式，100sps）
//   ACC : FE E2 + AX,AY,AZ 各 2 字节（大端 i16，±2g）—— 每 10 个 PPG 样本读一次(≈10Hz)
//   WHO : FE E3 + WHO_AM_I 1 字节（上电读一次，期望 0x68 —— 接线自检）
//   I2C: MAX30102@0x57 + MPU6050@0x68 共总线 | SCL=ball46 SDA=ball44 | UART tx=ball6 @9600 | LED=ball39
//   AD0 接 GND → MPU 地址 0x68
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

    // ---------- I2C（dev 可变：两台设备共总线）----------
    reg        i2c_start, i2c_rw;
    reg [6:0]  i2c_dev;
    reg [7:0]  i2c_reg, i2c_wdata, i2c_len;
    wire [7:0] i2c_rdata;
    wire       i2c_rvalid, i2c_done, i2c_busy, i2c_ack;
    i2c_master #(.CLK_HZ(12_000_000), .SCL_HZ(100_000)) u_i2c (
        .clk(clk), .rst(rst), .start(i2c_start), .rw(i2c_rw), .dev(i2c_dev),
        .reg_addr(i2c_reg), .wr_data(i2c_wdata), .rd_len(i2c_len),
        .rd_data(i2c_rdata), .rd_valid(i2c_rvalid), .done(i2c_done),
        .ack_err(i2c_ack), .busy(i2c_busy), .scl(scl), .sda(sda)
    );

    // ---------- UART 9600 ----------
    reg [7:0] uart_data;
    reg       uart_send;
    wire      uart_busy;
    uart_tx #(.CLK_HZ(12_000_000), .BAUD(9600)) u_uart (
        .clk(clk), .data(uart_data), .send(uart_send), .tx(tx), .busy(uart_busy)
    );

    // ---------- 配置表：MAX30102(0x57) + MPU6050(0x68) ----------
    localparam NCFG = 13;
    reg [3:0] cfg_idx;
    reg [6:0] cfg_dev;
    reg [7:0] cfg_reg, cfg_dat;
    always @(*) begin
        case (cfg_idx)
            4'd0:  begin cfg_dev=7'h57; cfg_reg=8'h09; cfg_dat=8'h40; end // MAX RESET
            4'd1:  begin cfg_dev=7'h57; cfg_reg=8'h04; cfg_dat=8'h00; end // FIFO_WR_PTR
            4'd2:  begin cfg_dev=7'h57; cfg_reg=8'h05; cfg_dat=8'h00; end // OVF
            4'd3:  begin cfg_dev=7'h57; cfg_reg=8'h06; cfg_dat=8'h00; end // FIFO_RD_PTR
            4'd4:  begin cfg_dev=7'h57; cfg_reg=8'h08; cfg_dat=8'h10; end // 无平均 + rollover
            4'd5:  begin cfg_dev=7'h57; cfg_reg=8'h09; cfg_dat=8'h02; end // MODE: HR-only
            4'd6:  begin cfg_dev=7'h57; cfg_reg=8'h0A; cfg_dat=8'h27; end // 100sps
            4'd7:  begin cfg_dev=7'h57; cfg_reg=8'h0C; cfg_dat=8'h24; end // LED1_PA
            4'd8:  begin cfg_dev=7'h68; cfg_reg=8'h6B; cfg_dat=8'h80; end // MPU 复位(等 100ms)
            4'd9:  begin cfg_dev=7'h68; cfg_reg=8'h6B; cfg_dat=8'h00; end // MPU 唤醒(等 50ms)
            4'd10: begin cfg_dev=7'h68; cfg_reg=8'h19; cfg_dat=8'h09; end // SMPLRT_DIV=9 → 100Hz
            4'd11: begin cfg_dev=7'h68; cfg_reg=8'h1A; cfg_dat=8'h03; end // CONFIG: DLPF 44Hz
            4'd12: begin cfg_dev=7'h68; cfg_reg=8'h1C; cfg_dat=8'h00; end // ACCEL_CONFIG: ±2g
            default: begin cfg_dev=7'h57; cfg_reg=8'h00; cfg_dat=8'h00; end
        endcase
    end

    // ---------- 主状态机 ----------
    localparam
        S_PWR=5'd0, S_CFG_SET=5'd1, S_CFG_GO=5'd2, S_CFG_WAIT=5'd3, S_DELAY=5'd4,
        S_WHO_SET=5'd5, S_WHO_GO=5'd6, S_WHO_WAIT=5'd7,
        S_WR_SET=5'd8, S_WR_GO=5'd9, S_WR_WAIT=5'd10,
        S_RDP_SET=5'd11, S_RDP_GO=5'd12, S_RDP_WAIT=5'd13,
        S_FIFO_SET=5'd14, S_FIFO_GO=5'd15, S_FIFO_WAIT=5'd16,
        S_ACC_SET=5'd17, S_ACC_GO=5'd18, S_ACC_WAIT=5'd19,
        S_TX_SET=5'd20, S_TX_GO=5'd21, S_TX_WAIT=5'd22, S_GAP=5'd23;

    localparam PWR_CY=32'd240_000;   // 20ms
    localparam RST_CY=32'd120_000;   // 10ms
    localparam CFG_CY=32'd12_000;    // 1ms
    localparam PRE_MPU_CY=32'd1_200_000;  // 100ms（MAX 配完，等 MPU 模块 LDO/上电就绪）
    localparam MPU_RST_CY=32'd1_200_000;  // 100ms（MPU 复位后）
    localparam MPU_CY=32'd600_000;        // 50ms（MPU 唤醒后）
    localparam POLL_CY=32'd6_000;    // 0.5ms
    localparam ACCEL_EVERY = 8'd10;  // 每 10 个 PPG 样本读一次 accel → ≈10Hz

    reg [4:0]  state;
    reg [31:0] dly, dly_target;
    reg [7:0]  wr, last_wr, acc_ctr, who;
    reg [3:0]  rx_idx;
    reg [7:0]  rxbuf [0:7];
    reg        rv_d;
    reg [3:0]  tx_idx, tx_len;
    reg [7:0]  tx_buf [0:7];
    reg [1:0]  tx_kind;      // 0=red, 1=who, 2=accel

    always @(posedge clk) begin
        uart_send <= 1'b0;
        rv_d <= i2c_rvalid;
        if (rst) begin
            state <= S_PWR; dly <= 0; dly_target <= PWR_CY;
            cfg_idx <= 0; rx_idx <= 0; wr <= 0; last_wr <= 8'hFF; acc_ctr <= 0; who <= 0;
            i2c_start <= 0; i2c_rw <= 0; i2c_dev <= 7'h57; i2c_reg <= 0; i2c_wdata <= 0; i2c_len <= 0;
            tx_idx <= 0; tx_len <= 0; tx_kind <= 0;
        end else begin
            case (state)
            // ---- 上电配置 ----
            S_PWR: if (dly >= dly_target) begin dly <= 0; state <= S_CFG_SET; end
                   else dly <= dly + 1'b1;
            S_CFG_SET: begin
                i2c_dev <= cfg_dev; i2c_rw <= 0; i2c_reg <= cfg_reg; i2c_wdata <= cfg_dat; i2c_len <= 1;
                i2c_start <= 1; state <= S_CFG_GO;
            end
            S_CFG_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_CFG_WAIT; end
            S_CFG_WAIT: if (i2c_done) begin
                if (cfg_idx == 4'd0) dly_target <= RST_CY;            // MAX 复位后 10ms
                else if (cfg_idx == 4'd7) dly_target <= PRE_MPU_CY;   // MAX 配完 → 等 MPU 就绪 100ms
                else if (cfg_idx == 4'd8) dly_target <= MPU_RST_CY;   // MPU 复位后 100ms
                else if (cfg_idx == 4'd9) dly_target <= MPU_CY;       // MPU 唤醒后 50ms
                else dly_target <= CFG_CY;
                dly <= 0; state <= S_DELAY;
            end
            S_DELAY: if (dly >= dly_target) begin
                dly <= 0;
                if (cfg_idx == NCFG-1) state <= S_WHO_SET;
                else begin cfg_idx <= cfg_idx + 4'd1; state <= S_CFG_SET; end
            end else dly <= dly + 1'b1;

            // ---- 上电自检：读 MPU WHO_AM_I(0x75) ----
            S_WHO_SET: begin
                rx_idx <= 0; i2c_dev <= 7'h68; i2c_rw <= 1; i2c_reg <= 8'h75; i2c_len <= 1;
                i2c_start <= 1; state <= S_WHO_GO;
            end
            S_WHO_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_WHO_WAIT; end
            S_WHO_WAIT: if (i2c_done) begin
                who <= rxbuf[0];
                tx_buf[0] <= 8'hFE; tx_buf[1] <= 8'hE3; tx_buf[2] <= rxbuf[0];
                tx_len <= 4'd3; tx_kind <= 2'd1; tx_idx <= 0; state <= S_TX_SET;
            end

            // ---- 轮询 MAX FIFO_WR_PTR ----
            S_WR_SET: begin
                rx_idx <= 0; i2c_dev <= 7'h57; i2c_rw <= 1; i2c_reg <= 8'h04; i2c_len <= 1;
                i2c_start <= 1; state <= S_WR_GO;
            end
            S_WR_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_WR_WAIT; end
            S_WR_WAIT: if (i2c_done) begin
                wr <= rxbuf[0];
                if (rxbuf[0] == last_wr) begin dly <= 0; dly_target <= POLL_CY; state <= S_GAP; end
                else state <= S_RDP_SET;
            end
            S_RDP_SET: begin
                i2c_dev <= 7'h57; i2c_rw <= 0; i2c_reg <= 8'h06;
                i2c_wdata <= (wr == 8'd0) ? 8'd31 : (wr - 8'd1);
                i2c_len <= 1; i2c_start <= 1; state <= S_RDP_GO;
            end
            S_RDP_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_RDP_WAIT; end
            S_RDP_WAIT: if (i2c_done) state <= S_FIFO_SET;
            S_FIFO_SET: begin
                rx_idx <= 0; i2c_dev <= 7'h57; i2c_rw <= 1; i2c_reg <= 8'h07; i2c_len <= 3;
                i2c_start <= 1; state <= S_FIFO_GO;
            end
            S_FIFO_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_FIFO_WAIT; end
            S_FIFO_WAIT: if (i2c_done) begin
                last_wr <= wr;
                if (acc_ctr != 8'hFF) acc_ctr <= acc_ctr + 8'd1;
                tx_buf[0] <= 8'hFE; tx_buf[1] <= 8'hE1; tx_buf[2] <= rxbuf[0] & 8'h03;
                tx_buf[3] <= rxbuf[1]; tx_buf[4] <= rxbuf[2];
                tx_len <= 4'd5; tx_kind <= 2'd0; tx_idx <= 0; state <= S_TX_SET;
            end

            // ---- 读 MPU 加速度 ACCEL_XOUT_H(0x3B) 6 字节 ----
            S_ACC_SET: begin
                rx_idx <= 0; i2c_dev <= 7'h68; i2c_rw <= 1; i2c_reg <= 8'h3B; i2c_len <= 6;
                i2c_start <= 1; state <= S_ACC_GO;
            end
            S_ACC_GO: if (i2c_busy) begin i2c_start <= 0; state <= S_ACC_WAIT; end
            S_ACC_WAIT: if (i2c_done) begin
                tx_buf[0] <= 8'hFE; tx_buf[1] <= 8'hE2;
                tx_buf[2] <= rxbuf[0]; tx_buf[3] <= rxbuf[1];
                tx_buf[4] <= rxbuf[2]; tx_buf[5] <= rxbuf[3];
                tx_buf[6] <= rxbuf[4]; tx_buf[7] <= rxbuf[5];
                tx_len <= 4'd8; tx_kind <= 2'd2; tx_idx <= 0; state <= S_TX_SET;
            end

            // ---- 通用发送 ----
            S_TX_SET: begin uart_data <= tx_buf[tx_idx]; uart_send <= 1'b1; state <= S_TX_GO; end
            S_TX_GO: begin uart_send <= 1'b0; if (uart_busy) state <= S_TX_WAIT; end
            S_TX_WAIT: if (!uart_busy) begin
                if (tx_idx == tx_len - 4'd1) begin
                    case (tx_kind)
                        2'd0: if (acc_ctr >= ACCEL_EVERY) begin acc_ctr <= 0; state <= S_ACC_SET; end
                              else begin dly <= 0; dly_target <= POLL_CY; state <= S_GAP; end
                        2'd1: state <= S_WR_SET;                       // WHO 发完 → 进主循环
                        default: begin dly <= 0; dly_target <= POLL_CY; state <= S_GAP; end
                    endcase
                end else begin tx_idx <= tx_idx + 4'd1; state <= S_TX_SET; end
            end

            S_GAP: if (dly >= dly_target) begin dly <= 0; state <= S_WR_SET; end
                   else dly <= dly + 1'b1;
            default: state <= S_PWR;
            endcase

            // 读回字节捕获
            if (i2c_rvalid && !rv_d && rx_idx < 4'd8) begin
                rxbuf[rx_idx] <= i2c_rdata;
                rx_idx        <= rx_idx + 4'd1;
            end
        end
    end
endmodule

`default_nettype wire
