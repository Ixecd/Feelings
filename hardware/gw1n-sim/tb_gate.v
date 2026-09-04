// tb_gate.v — GW1N 综合后网表门级仿真
// 验证：yosys 综合没改坏逻辑（iCESugar 教训：RTL 对、网表可能挂）
// 用法：iverilog -g2012 -o sim/gate.out cells_sim.v sim/synth_uart.v tb_gate.v
`timescale 1ns/1ps
module gate_tb;
    reg clk = 0;
    reg rx = 1;
    wire tx, led, err;
    integer j;

    uart_loopback dut (.tx(tx), .rx(rx), .clk(clk), .led(led), .err(err));

    // 50MHz 时钟
    always #10 clk = ~clk;

    // 发送任务：9600 波特（1 bit = 104160ns）
    task send_byte(input [7:0] data);
        integer i;
        begin
            rx = 0;                    // 起始位
            #104160;
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #104160;
            end
            rx = 1;                    // 停止位
            #104160;
        end
    endtask

    // 统计收发
    integer rx_good_count = 0;
    always @(posedge dut.rx_good) begin
        #1;   // 等 NBA 更新（网表里信号是不同 FF）
        rx_good_count = rx_good_count + 1;
        $display("rx_good #%0d @ %0tns 收=0x%02h nwords=%0d", rx_good_count, $time/1000, dut.push_byte, dut.nwords);
    end

    // 采样 tx 回发内容
    reg [3:0] gs_state = 0;
    reg [12:0] gs_cnt = 0;
    reg [7:0] gs_data = 0;
    reg [2:0] gs_bit = 0;
    reg prev_tx = 1;
    always @(posedge clk) prev_tx <= tx;

    always @(posedge clk) begin
        case (gs_state)
        0: if (prev_tx && !tx) begin gs_state <= 1; gs_cnt <= 0; end
        1: begin
            gs_cnt <= gs_cnt + 1;
            if (gs_cnt == 2603) begin gs_state <= 2; gs_cnt <= 0; gs_bit <= 0; end
        end
        2: begin
            gs_cnt <= gs_cnt + 1;
            if (gs_cnt == 5207) begin
                gs_cnt <= 0;
                gs_data[gs_bit] <= tx;
                if (gs_bit == 7) gs_state <= 3;
                else gs_bit <= gs_bit + 1;
            end
        end
        3: begin
            gs_cnt <= gs_cnt + 1;
            if (gs_cnt == 5207) begin
                gs_state <= 0;
                $display("FPGA 网表回发: 0x%02x", gs_data);
            end
        end
        endcase
    end

    initial begin
        clk = 0;
        rx = 1;
        #100;

        $display("=== 网表门级仿真：发 0x55 ===");
        send_byte(8'h55);
        #(104160 * 12);

        $display("=== 网表门级仿真：发 0xAA ===");
        send_byte(8'hAA);
        #(104160 * 12);

        $display("=== 网表门级仿真：发你好(UTF-8) ===");
        send_byte(8'hE4); send_byte(8'hBD); send_byte(8'hA0);
        send_byte(8'hE5); send_byte(8'hA5); send_byte(8'hBD);
        send_byte(8'h0A);
        #(104160 * 30);

        $display("=== 门级仿真结束 ===");
        $finish;
    end
endmodule
