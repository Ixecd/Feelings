// tb_stream.v — 验证 max30102_stream.v 的 UART 输出格式
`timescale 1ns/1ps
`default_nettype none

module tb_stream;
    wire clk;
    wire scl, sda, tx, led;

    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));
    max30102_stream dut (.scl(scl), .sda(sda), .tx(tx), .led(led));
    i2c_slave_model #(.ADDR(7'h57)) slave (.scl(scl), .sda(sda));
    pullup(sda);

    // 周期改变 slave 的 WR_PTR(0x04)，模拟新样本产生
    integer k;
    initial begin
        slave.mem[8'h04] = 8'h00;
        #25_000_000;              // 等 DUT 复位(65535) + 上电20ms + 配置
        for (k = 1; k <= 6; k = k + 1) begin
            slave.mem[8'h04] = k[7:0];   // 新样本
            slave.mem[8'h07] = 8'h10 + k; // 假 RED 数据（HR-only 3字节）
            slave.mem[8'h08] = 8'h20 + k;
            slave.mem[8'h09] = 8'h30 + k;
            #3_000_000;                   // 等一帧发完（DUT 轮询 0.5ms 一次）
        end
        $display("=== 仿真结束 ===");
        $finish;
    end

    // UART 解码：DUT uart DIV = 12e6/115200 = 104 clk/bit
    localparam BIT = 1250;   // 9600 @12MHz
    integer   ucnt = 0; reg [3:0] ubit = 0; reg [7:0] ush = 0; reg [2:0] ust = 0;
    reg txq = 1; integer rcnt = 0;
    always @(posedge clk) txq <= tx;
    always @(posedge clk) begin
        case (ust)
        3'd0: if (txq && !tx) begin ust <= 1; ucnt <= 0; end
        3'd1: if (ucnt == BIT/2 - 1) begin ust <= 2; ucnt <= 0; ubit <= 0; end
              else ucnt <= ucnt + 1;
        3'd2: if (ucnt == BIT - 1) begin
                  ucnt <= 0; ush[ubit] <= tx;
                  if (ubit == 7) ust <= 3; else ubit <= ubit + 1;
              end else ucnt <= ucnt + 1;
        3'd3: if (ucnt == BIT - 1) begin
                  ucnt <= 0; ust <= 0;
                  $display("  [uart] byte #%0d = 0x%02x", rcnt, ush);
                  rcnt <= rcnt + 1;
              end else ucnt <= ucnt + 1;
        endcase
    end
endmodule

`default_nettype wire
