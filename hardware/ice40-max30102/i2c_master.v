// i2c_master.v — 事务级 I2C master（一次一笔事务）
//   写: START → dev+W → reg → data → STOP
//   读: START → dev+W → reg → RESTART → dev+R → 读 N 字节(前 N-1 个 ACK, 末个 NACK) → STOP
//
// 用法:
//   置好 rw / dev / reg_addr / wr_data / rd_len，拉高 start 并保持，
//   直到 busy 拉高后即可拉低 start，等 done 脉冲（表示事务结束）。
//   读模式下每个字节读回时 rd_valid 拉高一拍(一个 tick)，rd_data 为该字节。
`default_nettype none

module i2c_master #(
    parameter CLK_HZ = 48_000_000,
    parameter SCL_HZ = 100_000
) (
    input  wire       clk,
    input  wire       rst,        // 同步复位, 高有效
    input  wire       start,      // 拉高启动（保持到 busy）
    input  wire       rw,         // 0=写, 1=读
    input  wire [6:0] dev,        // 7 位从机地址
    input  wire [7:0] reg_addr,   // 寄存器指针
    input  wire [7:0] wr_data,    // 写模式: 要写的字节
    input  wire [7:0] rd_len,     // 读模式: 读几个字节
    output reg  [7:0] rd_data,    // 当前读到的字节
    output reg        rd_valid,   // 每读到一个字节拉高一拍
    output reg        done,       // 事务结束脉冲
    output reg        ack_err,    // 从机 NACK 过（本事务内累积）
    output wire       busy,
    output wire       scl,
    inout  wire       sda
);

    localparam DIV4 = CLK_HZ / (SCL_HZ * 4);   // 一个 SCL 四分之一周期

    localparam
        S_IDLE   = 3'd0,
        S_START  = 3'd1,
        S_SEND   = 3'd2,
        S_ACKR   = 3'd3,
        S_RSTART = 3'd4,
        S_RECV   = 3'd5,
        S_MACK   = 3'd6,
        S_STOP   = 3'd7;

    reg [15:0] divc;
    wire tick = (divc == DIV4 - 1);
    always @(posedge clk)
        if (rst) divc <= 16'd0;
        else     divc <= tick ? 16'd0 : divc + 16'd1;

    reg scl_r, sda_oe, sda_out;
    assign scl = scl_r;
    assign sda = sda_oe ? sda_out : 1'bz;
    wire sda_in = sda;

    reg [2:0] st;
    reg [1:0] ph;
    reg [2:0] bitc;
    reg [7:0] sh;
    reg [2:0] step;
    reg [7:0] rd_left;
    reg       do_read;
    reg [6:0] devr;
    reg [7:0] regr, wrr;
    reg       busy_r;

    assign busy = busy_r;

    always @(posedge clk) begin
        rd_valid <= 1'b0;
        done     <= 1'b0;

        if (rst) begin
            st <= S_IDLE; ph <= 2'd0; bitc <= 3'd0; sh <= 8'd0; step <= 3'd0;
            scl_r <= 1'b1; sda_oe <= 1'b0; sda_out <= 1'b1;
            busy_r <= 1'b0; ack_err <= 1'b0; rd_left <= 8'd0; do_read <= 1'b0;
            rd_data <= 8'd0; devr <= 7'd0; regr <= 8'd0; wrr <= 8'd0;
        end else if (tick) begin
            case (st)
            // ---------------- IDLE ----------------
            S_IDLE: begin
                scl_r  <= 1'b1;
                sda_oe <= 1'b0;
                sda_out<= 1'b1;
                if (start && !busy_r) begin
                    busy_r  <= 1'b1;
                    do_read <= rw;
                    devr    <= dev;
                    regr    <= reg_addr;
                    wrr     <= wr_data;
                    rd_left <= rd_len;
                    ack_err <= 1'b0;
                    st      <= S_START;
                    ph      <= 2'd0;
                    step    <= 3'd0;
                end
            end
            // ---------------- START ----------------
            S_START: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b1; sda_oe <= 1'b1; sda_out <= 1'b1; ph <= 2'd1;
                end else if (ph == 2'd1) begin
                    sda_out <= 1'b0; ph <= 2'd2;                // SCL 高时 SDA 1→0
                end else if (ph == 2'd2) begin
                    scl_r <= 1'b0; ph <= 2'd3;
                end else begin
                    sh <= {devr, 1'b0};                          // 发 dev+W
                    st <= S_SEND; bitc <= 3'd0; ph <= 2'd0;
                end
            end
            // ---------------- 发送 8 位 ----------------
            S_SEND: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b1; sda_out <= sh[7]; ph <= 2'd1;
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;
                end else if (ph == 2'd2) begin
                    scl_r <= 1'b1; ph <= 2'd3;
                end else begin
                    scl_r <= 1'b0; sh <= {sh[6:0], 1'b0};
                    if (bitc == 3'd7) begin st <= S_ACKR; ph <= 2'd0; end
                    else begin bitc <= bitc + 3'd1; ph <= 2'd0; end
                end
            end
            // ---------------- 收从机 ACK ----------------
            S_ACKR: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b0; ph <= 2'd1;    // 释放 SDA
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;
                end else if (ph == 2'd2) begin
                    scl_r <= 1'b1; ack_err <= ack_err | sda_in; ph <= 2'd3;
                end else begin
                    scl_r <= 1'b0; ph <= 2'd0;
                    if (step == 3'd0) begin                    // addrW 发完 → 发 reg
                        step <= 3'd1; sh <= regr; st <= S_SEND; bitc <= 3'd0;
                    end else if (step == 3'd1) begin
                        if (do_read) begin st <= S_RSTART; end  // 读: 转 repeated start
                        else begin step <= 3'd2; sh <= wrr; st <= S_SEND; bitc <= 3'd0; end
                    end else begin                              // step==2
                        if (do_read) begin st <= S_RECV; bitc <= 3'd0; end
                        else begin st <= S_STOP; end
                    end
                end
            end
            // ---------------- 重复 START ----------------
            S_RSTART: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b1; sda_out <= 1'b1; ph <= 2'd1;
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;
                end else if (ph == 2'd2) begin
                    sda_out <= 1'b0; ph <= 2'd3;                    // SCL 高时 SDA 1→0
                end else begin
                    scl_r <= 1'b0; sh <= {devr, 1'b1}; step <= 3'd2;
                    st <= S_SEND; bitc <= 3'd0; ph <= 2'd0;
                end
            end
            // ---------------- 接收 8 位 ----------------
            S_RECV: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b0; ph <= 2'd1;      // 释放 SDA
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;
                end else if (ph == 2'd2) begin
                    scl_r <= 1'b1; sh <= {sh[6:0], sda_in}; ph <= 2'd3;   // 采样
                end else begin
                    scl_r <= 1'b0; ph <= 2'd0;
                    if (bitc == 3'd7) begin
                        rd_data <= sh; rd_valid <= 1'b1; st <= S_MACK;
                    end else bitc <= bitc + 3'd1;
                end
            end
            // ---------------- 主机回 ACK/NACK ----------------
            S_MACK: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b1;
                    sda_out <= (rd_left == 8'd1) ? 1'b1 : 1'b0;      // 最后一字节 NACK
                    ph <= 2'd1;
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;
                end else if (ph == 2'd2) begin
                    scl_r <= 1'b1; ph <= 2'd3;
                end else begin
                    scl_r <= 1'b0; ph <= 2'd0;
                    if (rd_left == 8'd1) st <= S_STOP;
                    else begin rd_left <= rd_left - 8'd1; st <= S_RECV; bitc <= 3'd0; end
                end
            end
            // ---------------- STOP ----------------
            S_STOP: begin
                if (ph == 2'd0) begin
                    scl_r <= 1'b0; sda_oe <= 1'b1; sda_out <= 1'b0; ph <= 2'd1;
                end else if (ph == 2'd1) begin
                    scl_r <= 1'b1; ph <= 2'd2;                       // SCL 升, SDA 仍低
                end else if (ph == 2'd2) begin
                    sda_out <= 1'b1; ph <= 2'd3;                     // SCL 高时 SDA 0→1
                end else begin
                    scl_r <= 1'b1; busy_r <= 1'b0; done <= 1'b1;
                    st <= S_IDLE; ph <= 2'd0;
                end
            end
            default: st <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
