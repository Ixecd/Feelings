`timescale 1ns/1ps
// tb_gate.v — 综合后网表门级仿真（真实参数：48MHz 时钟、104170ns/位）
// 用法：
//   yosys -p "read_verilog ../top.v; synth_ice40 -nobram -top top; write_verilog -noattr synth_top.v"
//   iverilog -g2012 -o gate.out cells_init.v synth_top.v tb_gate.v
module gate_tb;
    reg rx = 1;
    wire tx, led, err;
    integer j;
    top dut (.tx(tx), .rx(rx), .led(led), .err(err));

    integer rg = 0, tr = 0;
    always @(posedge dut.rx_good) begin
        #1;   // 等 NBA 更新完再读（网表里 push_byte 与 rx_good 是不同 FF）
        rg = rg + 1;
        $display("rx_good #%0d @ %0tns  push=0x%h  nwords=%0d", rg, $time/1000, dut.push_byte, dut.nwords);
    end
    always @(posedge dut.tx_req) begin
        #1;
        tr = tr + 1;
        $display("tx_req   #%0d @ %0tns  sends=0x%h  tstate=%0d", tr, $time/1000, dut.tx_data, dut.tstate);
    end

    // 周期性采样：观察状态机与计数器节奏（one-hot 编码下 rstate 是 [4:0]）
    initial begin
        fork
            forever begin #50000ns;
                $display("[SAMPLE] t=%0tns tstate=%0d tcnt=%0d tx_data=0x%h nwords=%0d",
                         $time/1000, dut.tstate, dut.tcnt, dut.tx_data, dut.nwords);
            end
        join_none
    end

    // TX 波形解码器：从起始边起按位中心采样，直读线上真实字节
    always @(tx) $display("TX EVENT: %b @ %0tns", tx, $time/1000);
    always @(dut.tx_data) $display("TXDATA=0x%h @ %0tns tstate=%0d tcnt=%0d", dut.tx_data, $time/1000, dut.tstate, dut.tcnt);
    reg [7:0] tshift;
    integer tj;
    initial begin
        forever begin
            @(negedge tx);
            #156300ns;   // b0 中心（起始边后 1.5 位）
            for (tj = 0; tj < 8; tj = tj + 1) begin
                #0;
                tshift[tj] = tx;
                $display("  [DEC] tj=%0d tx=%b t=%0tns", tj, tx, $time/1000);
                #104170ns;
            end
            $display("TXBYTE decoded=0x%h @ %0tns", tshift, $time/1000);
            #50000ns;
        end
    end

    task send_byte;
        input [7:0] b;
        begin
            rx = 1; #104170ns;
            rx = 0; #104170ns;
            for (j = 0; j < 8; j = j + 1) begin rx = b[j]; #104170ns; end
            rx = 1; #104170ns;
        end
    endtask

    initial begin
        #100000ns;
        $display("t=0: rx=%b err=%b rstate=%0d rx_sync=%b", rx, err, dut.rstate, dut.rx_sync);
        send_byte(8'hA5);
        #1500000ns;
        $display("FINAL rg=%0d tr=%0d nwords=%0d tx=%b", rg, tr, dut.nwords, tx);
        $finish;
    end
endmodule
