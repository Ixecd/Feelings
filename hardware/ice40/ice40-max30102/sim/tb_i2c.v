// tb_i2c.v — i2c_master 仿真验证（对 i2c_slave_model）
`timescale 1ns/1ps
`default_nettype none

module tb_i2c;
    reg clk = 0;
    reg rst = 1;

    // 命令
    reg        start = 0;
    reg        rw = 0;
    reg [6:0]  dev = 7'h57;
    reg [7:0]  reg_addr = 0;
    reg [7:0]  wr_data = 0;
    reg [7:0]  rd_len = 0;
    // 结果
    wire [7:0] rd_data;
    wire       rd_valid;
    wire       done;
    wire       ack_err;
    wire       busy;
    wire       scl;
    wire       sda;

    pullup(sda);

    i2c_master #(.CLK_HZ(4_000_000), .SCL_HZ(100_000)) dut (
        .clk(clk), .rst(rst), .start(start), .rw(rw), .dev(dev),
        .reg_addr(reg_addr), .wr_data(wr_data), .rd_len(rd_len),
        .rd_data(rd_data), .rd_valid(rd_valid), .done(done),
        .ack_err(ack_err), .busy(busy), .scl(scl), .sda(sda)
    );

    i2c_slave_model #(.ADDR(7'h57)) slave (.scl(scl), .sda(sda));

    always #125 clk = ~clk;      // 4MHz

    // 收集读回字节
    reg [7:0] rdbuf [0:15];
    integer   rdcnt = 0;
    reg       rv_d = 0;
    always @(posedge clk) begin
        rv_d <= rd_valid;
        if (rd_valid && !rv_d) begin
            rdbuf[rdcnt] <= rd_data;
            rdcnt <= rdcnt + 1;
            $display("    [tb] read byte #%0d = 0x%02x", rdcnt, rd_data);
        end
    end

    task do_write(input [7:0] ra, input [7:0] d);
        begin
            rw = 0; reg_addr = ra; wr_data = d; rd_len = 0;
            start = 1;
            wait (busy);
            @(posedge clk) start = 0;
            wait (done);
            @(posedge clk);
        end
    endtask

    task do_read(input [7:0] ra, input [7:0] len);
        begin
            rdcnt = 0;
            rw = 1; reg_addr = ra; wr_data = 0; rd_len = len;
            start = 1;
            wait (busy);
            @(posedge clk) start = 0;
            wait (done);
            @(posedge clk);
        end
    endtask

    integer k;
    // 状态监视
    wire dbg_tick = dut.tick;
    initial $monitor("  @%0t st=%0d ph=%0d start=%b rst=%b tick=%b scl=%b sda=%b busy=%b done=%b",
                     $time, dut.st, dut.ph, start, rst, dbg_tick, scl, sda, busy, done);
    // 看门狗：2ms 仿真时间强制结束
    initial begin
        #2_000_000;
        $display("!!! WATCHDOG 超时 @ %0t", $time);
        $finish;
    end

    initial begin
        $dumpfile("tb_i2c.vcd");
        $dumpvars(0, tb_i2c);
        rst = 1;
        #1000;
        rst = 0;
        #1000;
        $display("=== 开始 @ %0t ===", $time);

        $display("=== 测试1: 读 PART_ID(0xFF) 1 字节 ===");
        do_read(8'hFF, 8'd1);
        #2000;
        if (rdbuf[0] === 8'h15) $display("  >>> PASS: PART_ID=0x15"); else $display("  >>> FAIL: 得到 0x%02x", rdbuf[0]);

        $display("=== 测试2: 突发读 FIFO(0x07) 6 字节 ===");
        do_read(8'h07, 8'd6);
        #2000;
        if (rdbuf[0]===8'hA1 && rdbuf[1]===8'hB2 && rdbuf[2]===8'hC3 &&
            rdbuf[3]===8'hD4 && rdbuf[4]===8'hE5 && rdbuf[5]===8'hF6)
            $display("  >>> PASS: A1 B2 C3 D4 E5 F6");
        else
            $display("  >>> FAIL: %02x %02x %02x %02x %02x %02x",
                     rdbuf[0],rdbuf[1],rdbuf[2],rdbuf[3],rdbuf[4],rdbuf[5]);

        $display("=== 测试3: 写 0x09=0x55 再读回 ===");
        do_write(8'h09, 8'h55);
        #2000;
        do_read(8'h09, 8'd1);
        #2000;
        if (rdbuf[0] === 8'h55) $display("  >>> PASS: 写回 0x55"); else $display("  >>> FAIL: 得到 0x%02x", rdbuf[0]);

        $display("=== 全部测试结束 ===");
        $finish;
    end
endmodule

`default_nettype wire
