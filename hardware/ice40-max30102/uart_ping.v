// uart_ping.v — 隔离测试：无 I2C、固定循环发 FE E1 11 22 33 @9600
//   LED ~5.7Hz 快闪（其它固件是 ~0.7Hz，一眼看出烧没烧进去）
`default_nettype none

module uart_ping (
    output wire tx,
    output wire led
);
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));

    reg [22:0] hb;
    always @(posedge clk) hb <= hb + 1'b1;
    assign led = ~hb[20];          // ~5.7Hz 快闪

    reg [7:0] data;
    reg       send;
    wire      busy;
    uart_tx #(.CLK_HZ(12_000_000), .BAUD(9600)) u (
        .clk(clk), .data(data), .send(send), .tx(tx), .busy(busy)
    );

    reg [2:0]  idx;
    reg [19:0] gap;
    reg [1:0]  st;
    initial begin st = 2'd0; gap = 20'd0; idx = 3'd0; send = 1'b0; end

    always @(*) begin
        case (idx)
            3'd0: data = 8'hFE;
            3'd1: data = 8'hE1;
            3'd2: data = 8'h11;
            3'd3: data = 8'h22;
            default: data = 8'h33;
        endcase
    end

    always @(posedge clk) begin
        send <= 1'b0;
        case (st)
        2'd0: if (gap >= 20'd24000) begin gap <= 0; idx <= 0; st <= 2'd1; end  // ~2ms
              else gap <= gap + 1'b1;
        2'd1: begin send <= 1'b1; st <= 2'd2; end
        2'd2: begin send <= 1'b0; if (busy) st <= 2'd3; end
        2'd3: if (!busy) begin
                 if (idx == 3'd4) st <= 2'd0;
                 else begin idx <= idx + 3'd1; st <= 2'd1; end
              end
        endcase
    end
endmodule

`default_nettype wire
