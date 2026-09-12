`timescale 1ns/1ps
// tb_stream.v — 32 字节背靠背连发压测
// 无停止位间隔地连发，逼出推弹同拍场景；
// 期望：rx_good=32、tx_req=32、nwords 归零、逐字节一致
module tb_stream;
    reg clk = 0;
    always #10.417ns clk = ~clk;
    reg rx = 1;
    wire tx, led;
    integer j, k;
    top_sim #(.CYCLES(48), .HALF(24)) dut (.clk(clk), .tx(tx), .rx(rx), .led(led));

    integer rg = 0, tr = 0;
    always @(posedge dut.rx_good) begin
        #1;   // 等 NBA 更新完再读，避免读到旧值
        rg = rg + 1;
        $display("rx_good #%0d push=0x%h", rg, dut.push_byte);
    end
    always @(posedge dut.tx_req) begin
        #1;
        tr = tr + 1;
        $display("tx_req   #%0d sends=0x%h", tr, dut.tx_data);
    end

    task send_stream;
        input [7:0] data;
        begin
            rx = 1; #1000ns;
            rx = 0; #1000ns;
            for (j = 0; j < 8; j = j + 1) begin rx = data[j]; #1000ns; end
            rx = 1; #1000ns;
        end
    endtask

    initial begin
        #5000ns;
        for (k = 0; k < 32; k = k + 1) send_stream(8'h11 * k);
        #100000ns;
        $display("FINAL rx_good=%0d tx_req=%0d nwords=%0d", rg, tr, dut.nwords);
        $finish;
    end
endmodule
