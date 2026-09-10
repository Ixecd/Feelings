// tb_ppg.v — max30102_ppg 顶层仿真：配置→读 FIFO→UART 输出全流程
`timescale 1ns/1ps
`default_nettype none

module tb_ppg;
    wire clk;
    wire scl, sda, tx, led;

    SB_HFOSC #(.CLKHF_DIV("0b01")) osc (
        .CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk)
    );

    max30102_ppg dut (.scl(scl), .sda(sda), .tx(tx), .led(led));
    i2c_slave_model #(.ADDR(7'h57)) slave (.scl(scl), .sda(sda));
    pullup(sda);

    // ---- UART 解码（9600 @ CLK_HZ=24e6 → 5000 clk/bit；本桩 clk 25MHz 近似，用 5000）----
    localparam BIT = 2500;   // CLK_HZ/BAUD = 24e6/9600
    reg [15:0] ucnt = 0;
    reg [3:0]  ubit = 0;
    reg [7:0]  ush = 0;
    reg [2:0]  ustate = 0;
    reg        txq = 1;
    reg [7:0]  rbytes [0:31];
    integer    rcnt = 0;

    always @(posedge clk) txq <= tx;

    always @(posedge clk) begin
        case (ustate)
        3'd0: if (txq && !tx) begin ustate <= 1; ucnt <= 0; end
        3'd1: if (ucnt == BIT/2 - 1) begin ustate <= 2; ucnt <= 0; ubit <= 0; end
              else ucnt <= ucnt + 1;
        3'd2: if (ucnt == BIT - 1) begin
                  ucnt <= 0;
                  ush[ubit] <= tx;
                  if (ubit == 7) ustate <= 3; else ubit <= ubit + 1;
              end else ucnt <= ucnt + 1;
        3'd3: if (ucnt == BIT - 1) begin
                  ucnt <= 0; ustate <= 0;
                  rbytes[rcnt] = ush; rcnt = rcnt + 1;
                  $display("    [tb] UART #%0d = 0x%02x", rcnt-1, ush);
              end else ucnt <= ucnt + 1;
        endcase
    end

    initial begin
        $display("=== 顶层仿真开始 ===");
        // 跑到收到 8 个字节 (FE E1 + 6)
        wait (rcnt >= 8);
        $display("=== 收到首批 8 字节: %02x %02x %02x %02x %02x %02x %02x %02x ===",
                 rbytes[0],rbytes[1],rbytes[2],rbytes[3],rbytes[4],rbytes[5],rbytes[6],rbytes[7]);
        if (rbytes[0]===8'hFE && rbytes[1]===8'hE1 &&
            rbytes[2]===8'h01 && rbytes[5]===8'h03 && rbytes[6]===8'hE5)
            $display("  >>> PASS: 同步头+数据正确");
        else
            $display("  >>> FAIL");
        $finish;
    end

    // 看门狗 200ms 仿真时间
    initial begin
        #200_000_000;
        $display("!!! WATCHDOG 超时, 已收 %0d 字节", rcnt);
        $finish;
    end
endmodule

`default_nettype wire
