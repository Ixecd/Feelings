// UART Loopback — 步进 2a：步进 1 + FIFO16（仍串行：TX 期间不监听 RX）
// 与步进 1 的差别：
//   1. state 13 好帧 → 写入 FIFO（满则丢）→ 回 state 0
//   2. state 0：FIFO 非空 → 弹出 → TX；否则等起始位
//   3. TX 数据源从 rx_data 改为独立的 tx_data 寄存器
// 预期：单字符回显与步进 1 完全一致；
//       连发丢帧率同 working（TX 期间不监听，FIFO 只吸收排队）
module top (output tx, input rx, output led);
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (.CLKHF(clk), .CLKHFEN(1'b1), .CLKHFPU(1'b1));

    reg [25:0] hb;
    always @(posedge clk) hb <= hb + 1;

    parameter CYCLES = 5000;
    parameter HALF   = 2500;

    reg [17:0] cnt;
    reg [3:0]  state, bit_idx;
    reg [7:0]  rx_data, tx_data;
    reg        rx_led;
    assign led = hb[25] ^ rx_led;

    // ── FIFO 16×8（2a 验证机制用；64 深度留给 2b 双机版）──
    reg [7:0] fifo_mem [0:15];
    reg [3:0] wptr, rptr;
    reg [4:0] nwords;

    always @(posedge clk) begin
        if (state == 0) begin
            tx <= 1'b1;
            if (nwords != 0) begin
                // 弹出 → 进 TX
                tx_data <= fifo_mem[rptr];
                rptr <= rptr + 1;
                nwords <= nwords - 1;
                state <= 3; cnt <= 0; bit_idx <= 0;
            end else if (!rx) begin
                state <= 1; cnt <= 0;
            end
        end else if (state <= 2) begin // 1=half start, 2=data bits
            cnt <= cnt + 1;
            if (state == 1 && cnt == HALF - 1) begin state <= 2; cnt <= 0; bit_idx <= 0; end
            else if (state == 2 && cnt == CYCLES - 1) begin
                cnt <= 0;
                rx_data[bit_idx] <= rx;
                if (bit_idx == 7) begin
                    state <= 13; cnt <= 0; bit_idx <= 0;
                end else begin
                    bit_idx <= bit_idx + 1;
                end
            end
        end else if (state == 13) begin
            // 停止位采样：位中间读 rx
            cnt <= cnt + 1;
            if (cnt == CYCLES - 1) begin
                cnt <= 0;
                if (rx) begin
                    // 好帧 → 入 FIFO（满则丢）
                    if (nwords != 16) begin
                        fifo_mem[wptr] <= rx_data;
                        wptr <= wptr + 1;
                        nwords <= nwords + 1;
                    end
                    state <= 0;
                end else begin
                    // 帧错误 → 丢弃，回空闲
                    state <= 0;
                end
            end
        end else begin // state 3-12 = TX
            cnt <= cnt + 1;
            if (cnt == CYCLES - 1) begin
                cnt <= 0;
                case (state)
                    3:  begin tx <= 1'b0; state <= 4; end
                    4,5,6,7,8,9,10,11: begin tx <= tx_data[bit_idx]; bit_idx <= bit_idx+1; state <= state+1; end
                    12: begin tx <= 1'b1; state <= 0; rx_led <= ~rx_led; end
                endcase
            end
        end
    end
endmodule
