// tb_stream.v — 验证 max30102_stream v2：PPG(FE E1) + WHO(FE E3) + 加速度(FE E2)
`timescale 1ns/1ps
`default_nettype none

module tb_stream;
    wire clk;
    wire scl, sda, tx, led;

    SB_HFOSC #(.CLKHF_DIV("0b10")) osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));
    max30102_stream dut (.scl(scl), .sda(sda), .tx(tx), .led(led));
    i2c_slave_model #(.ADDR(7'h57)) slave (.scl(scl), .sda(sda));   // MAX30102
    i2c_slave_model #(.ADDR(7'h68)) mpu   (.scl(scl), .sda(sda));   // MPU6050
    pullup(sda);

    integer k;
    initial begin
        slave.mem[8'h04] = 8'h00;
        mpu.mem[8'h75] = 8'h68;                                     // WHO_AM_I
        mpu.mem[8'h3B] = 8'h01; mpu.mem[8'h3C] = 8'h02;             // AX = 0x0102
        mpu.mem[8'h3D] = 8'h03; mpu.mem[8'h3E] = 8'h04;             // AY = 0x0304
        mpu.mem[8'h3F] = 8'h05; mpu.mem[8'h40] = 8'h06;             // AZ = 0x0506
        #95_000_000;                       // 复位 + 上电 + 配置(含 MPU 唤醒 50ms) + WHO 自检
        for (k = 1; k <= 12; k = k + 1) begin
            slave.mem[8'h04] = k[7:0];     // 新样本
            slave.mem[8'h07] = 8'h10 + k;
            slave.mem[8'h08] = 8'h20 + k;
            slave.mem[8'h09] = 8'h30 + k;
            #8_000_000;
        end
        $display("=== 仿真结束 ===");
        $finish;
    end

    // ---- UART 解码 (9600 @12MHz) ----
    localparam BIT = 1250;
    integer   ucnt = 0; reg [3:0] ubit = 0; reg [7:0] ush = 0; reg [2:0] ust = 0;
    reg txq = 1; integer rcnt = 0;

    // ---- 帧组装 ----
    reg [7:0] data [0:5]; integer dn = 0; reg [3:0] fst = 0;
    task got_byte(input [7:0] by);
        begin
            case (fst)
            4'd0: if (by == 8'hFE) fst = 4'd1;
            4'd1: begin
                if      (by == 8'hE1) begin dn = 0; fst = 4'd2; end
                else if (by == 8'hE3) begin dn = 0; fst = 4'd3; end
                else if (by == 8'hE2) begin dn = 0; fst = 4'd4; end
                else fst = 4'd0;
            end
            4'd2: begin data[dn]=by; dn=dn+1; if (dn==3) begin
                    $display("  [FRAME] E1 RED = %02x %02x %02x", data[0],data[1],data[2]); fst=4'd0; end end
            4'd3: begin data[dn]=by; dn=dn+1; if (dn==1) begin
                    $display("  [FRAME] E3 WHO = %02x  %s", data[0], (data[0]==8'h68)?"OK(0x68)":"**FAIL**"); fst=4'd0; end end
            4'd4: begin data[dn]=by; dn=dn+1; if (dn==6) begin
                    $display("  [FRAME] E2 ACC = AX=%02x%02x AY=%02x%02x AZ=%02x%02x",
                             data[0],data[1],data[2],data[3],data[4],data[5]); fst=4'd0; end end
            default: fst = 4'd0;
            endcase
        end
    endtask

    always @(posedge clk) txq <= tx;
    always @(posedge clk) begin
        case (ust)
        3'd0: if (txq && !tx) begin ust <= 1; ucnt <= 0; end
        3'd1: if (ucnt == BIT/2 - 1) begin ust <= 2; ucnt <= 0; ubit <= 0; end
              else ucnt <= ucnt + 1;
        3'd2: if (ucnt == BIT - 1) begin
                  ucnt <= 0; ush[ubit] <= tx;
                  if (ubit == 7) ust <= 3; else ubit <= ubit + 1;
              end else ucnt <= ucnt + 1;
        3'd3: if (ucnt == BIT - 1) begin
                  ucnt <= 0; ust <= 0;
                  got_byte(ush);
                  rcnt <= rcnt + 1;
              end else ucnt <= ucnt + 1;
        endcase
    end
endmodule

`default_nettype wire
