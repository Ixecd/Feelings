// UART Loopback — minimal, 9600 baud
module top (input clk, input rx, output tx);
    reg baud_clk;
    reg [14:0] baud_cnt;
    always @(posedge clk)
        if (baud_cnt == 625) begin baud_clk <= ~baud_clk; baud_cnt <= 0; end
        else baud_cnt <= baud_cnt + 1;

    wire [7:0] rx_data;
    wire rx_done;

    uart_rx rx_inst (.clk(baud_clk), .rx(rx), .data(rx_data), .done(rx_done));
    uart_tx tx_inst (.clk(baud_clk), .data(rx_data), .start(rx_done), .tx(tx));
endmodule

module uart_rx (input clk, rx, output reg [7:0] data, output reg done);
    reg [3:0] state, bit_idx;
    always @(posedge clk) begin
        done <= 1'b0;
        if (state == 0) begin
            if (!rx) begin state <= 1; bit_idx <= 0; end
        end else begin
            data[bit_idx] <= rx; bit_idx <= bit_idx+1;
            if (state == 8) begin done <= 1'b1; state <= 0; end
            else state <= state+1;
        end
    end
endmodule

module uart_tx (input clk, input [7:0] data, input start, output reg tx);
    reg [3:0] state, bit_idx;
    always @(posedge clk) begin
        if (state == 0 && start) begin state <= 1; bit_idx <= 0; end
        else if (state != 0) begin
            case (state)
                1: begin tx <= 1'b0; state <= 2; end
                2,3,4,5,6,7,8,9: begin tx <= data[bit_idx]; bit_idx <= bit_idx+1; state <= state+1; end
                10: begin tx <= 1'b1; state <= 0; end
            endcase
        end
    end
endmodule