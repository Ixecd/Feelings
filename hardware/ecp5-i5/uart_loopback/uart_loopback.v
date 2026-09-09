// ECP5 (Colorlight i5) UART Loopback —— 从 GW1N 版移植
// 时钟 25MHz（i5 P3） / 9600 波特：CYCLES = 25e6/9600 ≈ 2604
// 引脚：tx=J17 (→DAPLink UART2→USB CDC), rx=H18, led=U16(板载D2), clk=P3
module uart_loopback (
    output reg tx,
    input  rx,
    input  clk,
    output led
);

    reg [24:0] hb;
    always @(posedge clk) hb <= hb + 1;

    reg [1:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[0], rx};

    parameter CYCLES = 2604;   // 25MHz / 9600
    parameter HALF   = 1302;

    reg [2:0]  rstate;
    reg [12:0] rcnt;
    reg [2:0]  rbit;
    reg [7:0]  rx_data;
    reg        rx_led;
    reg        rx_good;
    reg [7:0]  push_byte;

    reg [3:0]  tstate;
    reg [12:0] tcnt;
    reg [7:0]  tx_data;
    reg        tx_req;

    reg [7:0] fifo_mem [0:15];
    reg [3:0] wptr, rptr;
    reg [4:0] nwords;
    reg       push_pend;
    reg       pop_pend;

    initial begin
        hb = 0; rstate = 0; rcnt = 0; rbit = 0; rx_data = 0; rx_led = 0;
        rx_good = 0; push_byte = 0; rx_sync = 0;
        tstate = 0; tcnt = 0; tx_data = 0; tx_req = 0;
        wptr = 0; rptr = 0; nwords = 0; push_pend = 0; pop_pend = 0;
        tx = 1'b1;
    end

    assign led = hb[24];

    always @(posedge clk) begin
        rx_good <= 1'b0;
        case (rstate)
        0: if (rx_sync[1]) rstate <= 1;
        1: if (!rx_sync[1]) begin rstate <= 2; rcnt <= 13'd0; end
        2: begin
            rcnt <= rcnt + 13'd1;
            if (rcnt == HALF - 1) begin rstate <= 3; rcnt <= 13'd0; rbit <= 3'd0; end
        end
        3: begin
            rcnt <= rcnt + 13'd1;
            if (rcnt == CYCLES - 1) begin
                rcnt <= 13'd0;
                rx_data <= {rx_sync[1], rx_data[7:1]};
                if (rbit == 3'd7) begin rstate <= 4; rcnt <= 13'd0; end
                else rbit <= rbit + 3'd1;
            end
        end
        4: begin
            rcnt <= rcnt + 13'd1;
            if (rcnt == CYCLES - 1) begin
                rcnt <= 13'd0;
                rstate <= 3'd0;
                if (rx_sync[1]) begin
                    rx_led <= ~rx_led;
                    push_byte <= rx_data;
                    rx_good <= 1'b1;
                end
            end
        end
        default: rstate <= 3'd0;
        endcase
    end

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
                tx <= 1'b0;
                tstate <= 4;
            end
        end
        4,5,6,7,8,9,10,11: begin
            tcnt <= tcnt + 13'd1;
            if (tcnt == CYCLES - 1) begin
                tcnt <= 13'd0;
                tx <= tx_data[0];
                tx_data <= {1'b0, tx_data[7:1]};
                tstate <= tstate + 4'd1;
            end
        end
        12: begin
            tcnt <= tcnt + 13'd1;
            if (tcnt == CYCLES - 1) begin
                tcnt <= 13'd0;
                tx <= 1'b1;
                tstate <= 0;
            end
        end
        default: tstate <= 0;
        endcase
    end

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
