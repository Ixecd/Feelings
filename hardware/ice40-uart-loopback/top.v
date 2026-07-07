// Fixed reply test: always echo 'Z' — 2400 baud
module top (input clk, input rx, output tx);
    parameter DIV = 12_000_000 / 2400; // 5000

    wire [7:0] rx_data;
    wire       rx_done;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    uart_rx #(.DIV(DIV)) rx_inst (.clk(clk), .rx(rx), .data(rx_data), .done(rx_done));
    uart_tx #(.DIV(DIV)) tx_inst (.clk(clk), .data(tx_data), .start(tx_start), .tx(tx), .busy(tx_busy));

    always @(posedge clk) begin
        if (rx_done && !tx_busy) begin
            tx_data  <= 8'h5A; // 'Z'
            tx_start <= 1'b1;
        end else
            tx_start <= 1'b0;
    end
endmodule

module uart_rx #(parameter DIV=5000) (
    input clk, rx, output reg [7:0] data, output reg done
);
    reg [15:0] counter;
    reg [3:0]  state, bit_idx;
    reg [3:0]  rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[2:0], rx};
    always @(posedge clk) begin
        done <= 1'b0;
        if (state == 0) begin
            if (rx_sync == 4'b0000) begin counter <= DIV/2; state <= 1; bit_idx <= 0; end
        end else if (counter == 0) begin
            counter <= DIV;
            if (state >= 1 && state <= 8) begin data[bit_idx] <= rx; bit_idx <= bit_idx + 1; end
            if (state == 9) begin done <= 1'b1; state <= 0; end
            else state <= state + 1;
        end else counter <= counter - 1;
    end
endmodule

module uart_tx #(parameter DIV=5000) (
    input clk, input [7:0] data, input start, output reg tx, output reg busy
);
    reg [15:0] counter;
    reg [3:0]  state, bit_idx;
    always @(posedge clk) begin
        if (state == 0 && start) begin busy <= 1'b1; state <= 1; counter <= DIV; bit_idx <= 0; end
        else if (state != 0 && counter == 0) begin
            counter <= DIV;
            case (state)
                1: begin tx <= 1'b0; state <= 2; end
                2,3,4,5,6,7,8,9: begin tx <= data[bit_idx]; bit_idx <= bit_idx + 1; state <= state + 1; end
                10: begin tx <= 1'b1; busy <= 1'b0; state <= 0; end
            endcase
        end else if (state != 0) counter <= counter - 1;
    end
endmodule