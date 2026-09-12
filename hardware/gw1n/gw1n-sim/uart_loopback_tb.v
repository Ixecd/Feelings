// GW1N UART Loopback testbench v2
// 简化：9600 波特用更快的虚拟时钟？不——UART 波特率是真实的
// 但 50MHz 仿真 9600 波特太慢（1bit=104us, 一个字节~1ms, 仿真要 20M+ 周期）
// 解法：用更高波特率仿真（如 1M 波特）验证逻辑，真实 9600 靠参数
// 这里用 50MHz 时钟，仿真波特率设 500000 (500K)，bit=100clk=2us
// 逻辑不变（参数化波特率），验证"收发正确"即可
`timescale 1ns/1ps
module uart_loopback_tb;
    reg clk;
    reg rx;
    wire tx;
    wire led, err;

    uart_loopback uut (
        .tx(tx),
        .rx(rx),
        .clk(clk),
        .led(led),
        .err(err)
    );

    // 引出内部状态观察
    wire [2:0] rstate = uut.rstate;
    wire [3:0] tstate = uut.tstate;
    wire [4:0] nwords_w = uut.nwords;

    // 50MHz 时钟
    always #10 clk = ~clk;

    // 仿真用 500K 波特：1 bit = 100 clk = 2000ns
    // （uut 里 CYCLES=5208 是 9600 的，这里覆盖不了参数，先按模块实际 9600 跑短测试）
    // 9600 波特：1 bit = 5208 clk = 104160ns
    // 为缩短仿真，只发 1 个字节验证
    localparam BIT_NS = 104160;

    // 记录收到的字节
    integer rx_count;
    reg [7:0] got_byte;

    // 检测 tx 起始位（下降沿），采样后续位
    reg prev_tx;
    always @(posedge clk) prev_tx <= tx;

    reg [3:0] samp_state;
    reg [12:0] samp_cnt;
    reg [7:0]  samp_data;
    reg [2:0]  samp_bit;

    always @(posedge clk) begin
        case (samp_state)
        0: begin // 等 tx 下降沿（起始位）
            if (prev_tx && !tx) begin
                samp_state <= 1;
                samp_cnt <= 0;
            end
        end
        1: begin // 过半起始位
            samp_cnt <= samp_cnt + 1;
            if (samp_cnt == 2603) begin samp_state <= 2; samp_cnt <= 0; samp_bit <= 0; end
        end
        2: begin // 采数据位（每 bit 中点）
            samp_cnt <= samp_cnt + 1;
            if (samp_cnt == 5207) begin
                samp_cnt <= 0;
                samp_data[samp_bit] <= tx;
                if (samp_bit == 7) begin samp_state <= 3; end
                else samp_bit <= samp_bit + 1;
            end
        end
        3: begin // 等停止位结束
            samp_cnt <= samp_cnt + 1;
            if (samp_cnt == 5207) begin
                samp_state <= 0;
                rx_count <= rx_count + 1;
                got_byte <= samp_data;
                $display("FPGA 回发字节 #%0d: 0x%02x", rx_count + 1, samp_data);
            end
        end
        endcase
    end

    // 发送一个字节
    task send_byte(input [7:0] data);
        integer i;
        begin
            rx = 1'b0;                    // 起始位
            #BIT_NS;
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_NS;
            end
            rx = 1'b1;                    // 停止位
            #BIT_NS;
        end
    endtask

    initial begin
        clk = 0;
        rx = 1'b1;
        rx_count = 0;
        prev_tx = 1'b1;
        samp_state = 0; samp_cnt = 0; samp_data = 0; samp_bit = 0;
        #100;

        $display("=== 发 0x55 ===");
        send_byte(8'h55);
        #(BIT_NS * 12);   // 等 FPGA 回发

        $display("=== 发 0xAA ===");
        send_byte(8'hAA);
        #(BIT_NS * 12);

        // ── 连续多字节测试（模拟中文"你好"UTF-8：E4 BD A0 E5 A5 BD + 换行 0A）──
        $display("=== 连续发一串字节（模拟中文你好 UTF-8）===");
        send_byte(8'hE4);  // 你(UTF-8 byte1)
        send_byte(8'hBD);  // 你(byte2)
        send_byte(8'hA0);  // 你(byte3)
        send_byte(8'hE5);  // 好(byte1)
        send_byte(8'hA5);  // 好(byte2)
        send_byte(8'hBD);  // 好(byte3)
        send_byte(8'h0A);  // 换行
        // 等所有字节被 FIFO 缓冲 + 逐个回发（7 字节 × 收发时间）
        #(BIT_NS * 30);

        $display("=== 测试结束，共收到 %0d 字节 ===", rx_count);
        $finish;
    end

    initial begin
        $dumpfile("uart_loopback.vcd");
        $dumpvars(0, uart_loopback_tb);
    end
endmodule
