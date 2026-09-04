// GW1N UART Loopback — 从 iCE40 step2b 移植
// 结构（复用 step2b 已验证逻辑）：
//   块 1（RX 机）：五态（等空闲高/等起始边/半位/8数据/停止），移位装载
//   块 2（TX 机）：移位发出 tx_data[0] + {1'b0, tx_data[7:1]}
//   块 3（结算） ：FIFO16 唯一写点，消费 rx_good/tx_req 脉冲
//
// 时钟：外部 50MHz 晶振（FG202 板 IO98 = CLK_IN），不是内部振荡器
//   50MHz / 9600 波特 ≈ 5208 周期/位
// 引脚（FG202）：tx=IO15(经 CH340 RXD), rx=IO12(经 CH340 TXD), clk=IO98
module uart_loopback (
    output reg tx,      // UART 发送 → CH340 RXD → 电脑（块内赋值，reg）
    input  rx,          // UART 接收 ← CH340 TXD ← 电脑
    input  clk,         // 50MHz 外部晶振（IO98）
    output led,
    output err
);

    reg [25:0] hb;
    always @(posedge clk) hb <= hb + 1;

    // ── 异步输入同步器：rx 打两拍，防亚稳态 ──
    reg [1:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[0], rx};

    assign err = rx_sync[1];   // 诊断灯镜像 FPGA 眼中的 RX 线

    parameter CYCLES = 5208;   // 50MHz / 9600
    parameter HALF   = 2604;

    // ── RX 机 ──
    reg [2:0]  rstate;      // 0 等空闲高 1 等起始边 2 半位 3 数据 4 停止
    reg [12:0] rcnt;
    reg [2:0]  rbit;
    reg [7:0]  rx_data;     // 移位装载
    reg        rx_led;
    reg        rx_good;
    reg [7:0]  push_byte;

    // ── TX 机 ──
    reg [3:0]  tstate;      // 0 空闲 3-12 发送序列
    reg [12:0] tcnt;
    reg [7:0]  tx_data;     // 移位发出
    reg        tx_req;

    // ── FIFO 16×8（结算块独占）──
    (* ram_style = "registers" *) reg [7:0] fifo_mem [0:15];  // 纯寄存器，避免块RAM
    reg [3:0] wptr, rptr;
    reg [4:0] nwords;
    reg       push_pend;
    reg       pop_pend;

    // 仿真初始化（FPGA 上电默认 0，仿真寄存器默认 X，需 initial 置 0）
    initial begin
        hb = 0; rstate = 0; rcnt = 0; rbit = 0; rx_data = 0; rx_led = 0;
        rx_good = 0; push_byte = 0; rx_sync = 0;
        tstate = 0; tcnt = 0; tx_data = 0; tx_req = 0;
        wptr = 0; rptr = 0; nwords = 0; push_pend = 0; pop_pend = 0;
        tx = 1'b1;
    end

    assign led = hb[25] ^ rx_led;

    // ═════════ 块 1：RX 机 ═════════
    always @(posedge clk) begin
        rx_good <= 1'b0;
        case (rstate)
        0: if (rx_sync[1]) rstate <= 1;          // 等空闲高（防上电幻影帧）
        1: if (!rx_sync[1]) begin rstate <= 2; rcnt <= 13'd0; end   // 起始边
        2: begin
            rcnt <= rcnt + 13'd1;
            if (rcnt == HALF - 1) begin rstate <= 3; rcnt <= 13'd0; rbit <= 3'd0; end
        end
        3: begin
            rcnt <= rcnt + 13'd1;
            if (rcnt == CYCLES - 1) begin
                rcnt <= 13'd0;
                rx_data <= {rx_sync[1], rx_data[7:1]};   // 移位装载
                if (rbit == 3'd7) begin rstate <= 4; rcnt <= 13'd0; end
                else rbit <= rbit + 3'd1;
            end
        end
        4: begin // 停止位采样
            rcnt <= rcnt + 13'd1;
            if (rcnt == CYCLES - 1) begin
                rcnt <= 13'd0;
                rstate <= 3'd0;
                if (rx_sync[1]) begin
                    rx_led <= ~rx_led;
                    push_byte <= rx_data;
                    rx_good <= 1'b1;
                end
                // 帧错误：静默丢弃
            end
        end
        default: rstate <= 3'd0;
        endcase
    end

    // ═════════ 块 2：TX 机 ═════════
    always @(posedge clk) begin
        tx_req <= 1'b0;
        case (tstate)
        0: begin
            tx <= 1'b1;
            if (nwords != 0) begin
                tx_data <= fifo_mem[rptr];
                tx_req <= 1'b1;
                tstate <= 3; tcnt <= 13'd0;
            end
        end
        3: begin
            tcnt <= tcnt + 13'd1;
            if (tcnt == CYCLES - 1) begin
                tcnt <= 13'd0;
                tx <= 1'b0;                    // 起始位
                tstate <= 4;
            end
        end
        4,5,6,7,8,9,10,11: begin
            tcnt <= tcnt + 13'd1;
            if (tcnt == CYCLES - 1) begin
                tcnt <= 13'd0;
                tx <= tx_data[0];               // LSB 先出
                tx_data <= {1'b0, tx_data[7:1]};
                tstate <= tstate + 4'd1;
            end
        end
        12: begin
            tcnt <= tcnt + 13'd1;
            if (tcnt == CYCLES - 1) begin
                tcnt <= 13'd0;
                tx <= 1'b1;                    // 停止位
                tstate <= 0;
            end
        end
        default: tstate <= 0;
        endcase
    end

    // ═════════ 块 3：FIFO 结算 ═════════
    always @(posedge clk) begin
        if (push_pend && pop_pend) begin
            fifo_mem[wptr] <= push_byte;
            wptr <= wptr + 4'd1;
            if (wptr != rptr) rptr <= rptr + 4'd1;
            push_pend <= 1'b0;
            pop_pend  <= 1'b0;
        end else if (push_pend) begin
            fifo_mem[wptr] <= push_byte;
            wptr <= wptr + 4'd1;
            nwords <= nwords + 5'd1;
            push_pend <= 1'b0;
        end else if (pop_pend) begin
            rptr <= rptr + 4'd1;
            nwords <= nwords - 5'd1;
            pop_pend <= 1'b0;
        end

        if (rx_good && (nwords != 5'd16))
            push_pend <= 1'b1;
        if (tx_req)
            pop_pend <= 1'b1;
    end
endmodule
