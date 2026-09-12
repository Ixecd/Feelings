// uart_tx.v — 8N1 UART 发送
`default_nettype none

module uart_tx #(
    parameter CLK_HZ = 48_000_000,
    parameter BAUD   = 9600
) (
    input             clk,
    input      [7:0]  data,
    input             send,
    output reg        tx,
    output reg        busy
);
    localparam DIV = CLK_HZ / BAUD;      // 5000 @48MHz/9600

    reg [15:0] cnt;
    reg [3:0]  bitc;
    reg [9:0]  sh;

    initial begin tx = 1; busy = 0; cnt = 0; bitc = 0; sh = 0; end

    always @(posedge clk) begin
        if (!busy) begin
            tx <= 1'b1;
            if (send) begin
                sh   <= {1'b1, data, 1'b0};   // 停止位 + 数据 + 起始位
                bitc <= 0;
                cnt  <= 0;
                busy <= 1'b1;
            end
        end else begin
            if (cnt == DIV-1) begin
                cnt <= 0;
                tx  <= sh[0];
                sh  <= {1'b1, sh[9:1]};
                if (bitc == 9) busy <= 1'b0;
                else bitc <= bitc + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
