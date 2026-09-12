// UART Loopback — internal 24MHz, 2500/bit @9600, single always-block handshake
module top (output tx, input rx, output led);
    wire clk;
    SB_HFOSC #(.CLKHF_DIV("0b00")) osc (.CLKHF(clk), .CLKHFEN(1'b1), .CLKHFPU(1'b1));

    reg [25:0] hb;
    always @(posedge clk) hb <= hb + 1;

    parameter CYCLES = 5000;
    parameter HALF   = 2500;

    reg [17:0] cnt;
    reg [3:0]  state, bit_idx;
    reg [7:0]  rx_data;
    reg        rx_led;
    assign led = hb[25] ^ rx_led;

    always @(posedge clk) begin
        // ── RX ──
        if (state == 0) begin
            tx <= 1'b1;
            if (!rx) begin state <= 1; cnt <= 0; end
        end else if (state <= 2) begin // 1=half start, 2=data bits
            cnt <= cnt + 1;
            if (state == 1 && cnt == HALF - 1) begin state <= 2; cnt <= 0; bit_idx <= 0; end
            else if (state == 2 && cnt == CYCLES - 1) begin
                cnt <= 0;
                rx_data[bit_idx] <= rx;
                if (bit_idx == 7) begin
                    // RX done → start TX immediately
                    state <= 3; cnt <= 0; bit_idx <= 0;
                end else begin
                    bit_idx <= bit_idx + 1;
                end
            end
        end else begin // state >= 3 = TX
            cnt <= cnt + 1;
            if (cnt == CYCLES - 1) begin
                cnt <= 0;
                case (state)
                    3:  begin tx <= 1'b0; state <= 4; end
                    4,5,6,7,8,9,10,11: begin tx <= rx_data[bit_idx]; bit_idx <= bit_idx+1; state <= state+1; end
                    12: begin tx <= 1'b1; state <= 0; rx_led <= ~rx_led; end
                endcase
            end
        end
    end
endmodule
