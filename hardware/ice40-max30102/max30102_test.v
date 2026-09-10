// max30102_test.v — iCESugar(iCE40UP5K) 读 MAX30102 PART_ID 验证
// clk: 内部 48MHz HFOSC | I2C: scl=46, sda=44 | UART: tx=6 | led=39
// 流程: START → 写 0xAE(addr+W) → 写 0xFF(REG_PART_ID) → START →
//       写 0xAF(addr+R) → 读 1 字节 → NACK → STOP → UART 发送该字节
// 期望 PART_ID = 0x15 (0xFE 是 REVISION_ID=0x03)
`default_nettype none

module max30102_test (
    output reg scl,
    inout      sda,
    output reg tx,
    output     led
);

    // ---------- 内部 48MHz 振荡器 ----------
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    // 心跳灯（低电平亮）
    reg [24:0] hb;
    always @(posedge clk) hb <= hb + 1'b1;
    assign led = ~hb[24];

    // ---------- SDA 三态 ----------
    reg sda_oe, sda_out;
    assign sda = sda_oe ? sda_out : 1'bz;
    wire sda_in = sda;

    // ---------- 位相位分频 (~100kHz SCL) ----------
    localparam DIV = 240;              // 48MHz/240 = 200kHz 相位率
    reg [15:0] divc;
    wire tick = (divc == DIV-1);
    always @(posedge clk)
        divc <= tick ? 16'd0 : divc + 16'd1;

    // ---------- 常量 ----------
    localparam A_W = 8'hAE;            // 0x57<<1 | W
    localparam A_R = 8'hAF;            // 0x57<<1 | R
    localparam REG = 8'hFF;            // PART_ID register (0xFE = REVISION_ID)

    // ---------- 事务状态 ----------
    localparam
        S_IDLE = 4'd0, S_START = 4'd1, S_TX = 4'd2, S_ACK = 4'd3,
        S_RX   = 4'd4, S_NACK  = 4'd5, S_STOP = 4'd6, S_DONE = 4'd7;

    reg [3:0] st;
    reg [1:0] ph;                      // 相位
    reg [2:0] bc;                      // bit 计数
    reg [7:0] sh;                      // 移位寄存器
    reg [2:0] seq;                     // 序列 0..6
    reg [7:0] part_id;

    // ---------- UART 发送 ----------
    reg [7:0] uart_data;
    reg       uart_send;
    wire      uart_busy;
    reg [1:0] send_st;
    reg [25:0] resend;

    uart_tx #(.CLK_HZ(48000000), .BAUD(9600)) u_tx (
        .clk(clk), .data(uart_data), .send(uart_send),
        .tx(tx), .busy(uart_busy)
    );

    initial begin
        st = 0; ph = 0; bc = 0; sh = 0; seq = 0;
        scl = 1; sda_oe = 0; sda_out = 1;
        uart_send = 0; send_st = 0; uart_data = 0; part_id = 0;
    end

    always @(posedge clk) begin
        uart_send <= 1'b0;

        if (tick) begin
            case (st)
            // ---- IDLE ----
            S_IDLE: begin
                scl <= 1; sda_oe <= 1; sda_out <= 1;
                seq <= 0; ph <= 0; st <= S_START;
            end

            // ---- START: SCL=1 时 SDA 1→0 ----
            S_START: begin
                if (ph == 0) begin                   // SCL 高, SDA 高
                    scl <= 1; sda_oe <= 1; sda_out <= 1; ph <= 1;
                end else if (ph == 1) begin          // SCL 仍高, SDA 下降 = START
                    sda_out <= 0; ph <= 2;
                end else begin                        // SCL 下降, 进入数据
                    scl <= 0; ph <= 0;
                    if (seq == 3'd3) begin sh <= A_R; seq <= 3'd4; end  // repeated
                    else             begin sh <= A_W; seq <= 3'd1; end  // initial
                    bc <= 3'd7;
                    st <= S_TX;
                end
            end

            // ---- 发送 8 位 ----
            S_TX: begin
                if (ph == 0) begin
                    scl <= 0; sda_oe <= 1; sda_out <= sh[7]; ph <= 1;
                end else begin
                    scl <= 1; ph <= 0;
                    if (bc == 0) st <= S_ACK;
                    else begin sh <= {sh[6:0], 1'b0}; bc <= bc - 3'd1; end
                end
            end

            // ---- 收 ACK ----
            S_ACK: begin
                if (ph == 0) begin
                    scl <= 0; sda_oe <= 0; ph <= 1;  // 释放 SDA
                end else begin
                    scl <= 1; ph <= 0;
                    case (seq)
                    3'd1: begin seq <= 3'd2; sh <= REG; bc <= 3'd7; st <= S_TX; end
                    3'd2: begin seq <= 3'd3; st <= S_START; end     // repeated start
                    3'd4: begin seq <= 3'd5; bc <= 3'd7; st <= S_RX; end
                    default: st <= S_STOP;
                    endcase
                end
            end

            // ---- 接收 8 位 ----
            S_RX: begin
                if (ph == 0) begin
                    scl <= 0; sda_oe <= 0; ph <= 1;
                end else begin
                    scl <= 1;
                    if (bc == 0) begin part_id <= {sh[6:0], sda_in}; st <= S_NACK; end
                    else begin sh <= {sh[6:0], sda_in}; bc <= bc - 3'd1; end
                    ph <= 0;
                end
            end

            // ---- 发 NACK ----
            S_NACK: begin
                if (ph == 0) begin scl <= 0; sda_oe <= 1; sda_out <= 1; ph <= 1; end
                else begin scl <= 1; ph <= 0; st <= S_STOP; end
            end

            // ---- STOP: SCL=1 时 SDA 0→1 ----
            S_STOP: begin
                if (ph == 0) begin scl <= 0; sda_oe <= 1; sda_out <= 0; ph <= 1; end
                else if (ph == 1) begin scl <= 1; ph <= 2; end       // SCL 升，SDA 仍低
                else begin sda_out <= 1; ph <= 0; st <= S_DONE; end  // SDA 升 = STOP
            end

            // ---- DONE ----
            S_DONE: begin
                scl <= 1; sda_oe <= 1; sda_out <= 1;
                st <= S_DONE;
            end
            endcase
        end

        // ---- 完成后 UART 发送 part_id ----
        case (send_st)
        2'd0: if (st == S_DONE) begin uart_data <= part_id; send_st <= 2'd1; end
        2'd1: begin uart_send <= 1'b1; resend <= 0; send_st <= 2'd2; end
        2'd2: if (resend == 26'd47_999_999) begin resend <= 0; send_st <= 2'd0; end
              else resend <= resend + 1'b1;   // ~1s 后重发 part_id
        endcase
    end
endmodule


// ================= UART TX =================
module uart_tx #(
    parameter CLK_HZ = 48000000,
    parameter BAUD   = 9600
) (
    input             clk,
    input      [7:0]  data,
    input             send,
    output reg        tx,
    output reg        busy
);
    localparam DIV = CLK_HZ / BAUD;      // 5000 @48MHz/9600

    reg [15:0] cnt;
    reg [3:0]  bitc;
    reg [9:0]  sh;

    initial begin tx = 1; busy = 0; cnt = 0; bitc = 0; sh = 0; end

    always @(posedge clk) begin
        if (!busy) begin
            tx <= 1'b1;
            if (send) begin
                sh   <= {1'b1, data, 1'b0};  // 停止位 + 数据 + 起始位
                bitc <= 0;
                cnt  <= 0;
                busy <= 1'b1;
            end
        end else begin
            if (cnt == DIV-1) begin
                cnt <= 0;
                tx  <= sh[0];
                sh  <= {1'b1, sh[9:1]};
                if (bitc == 9) busy <= 1'b0;
                else bitc <= bitc + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
