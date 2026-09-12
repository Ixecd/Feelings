// i2c_slave_model.v — 仿真用 I2C 从机模型（不可综合）
//   模拟 MAX30102：地址 0x57，几个寄存器，支持突发读自增
`timescale 1ns/1ps
`default_nettype none

module i2c_slave_model #(
    parameter [6:0] ADDR = 7'h57
) (
    input wire scl,
    inout wire sda
);
    reg [7:0] mem [0:255];
    reg sda_oe, sda_out;
    assign sda = sda_oe ? sda_out : 1'bz;
    wire sda_in = sda;

    reg [7:0] byte_sh;
    integer   n;          // 当前字节内已完成的 bit 数 0..8
    reg       recv;       // 1=主机->从机, 0=从机->主机
    reg       ack_needed;
    reg       after_start;
    reg       rw;
    reg       ptr_set;
    reg [7:0] ptr;
    integer   i;

    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
        mem[8'hFF] = 8'h15;   // PART_ID
        mem[8'hFE] = 8'h03;   // REVISION_ID
        mem[8'h04] = 8'h05;   // FIFO_WR_PTR
        mem[8'h07] = 8'hA1; mem[8'h08] = 8'hB2; mem[8'h09] = 8'hC3;
        mem[8'h0A] = 8'hD4; mem[8'h0B] = 8'hE5; mem[8'h0C] = 8'hF6;
        n = 0; recv = 1; ack_needed = 0; after_start = 1; rw = 0;
        ptr_set = 0; ptr = 0; sda_oe = 0; sda_out = 0; byte_sh = 0;
    end

    // START: SCL 高时 SDA 下降
    always @(negedge sda) if (scl) begin
        n = 0; recv = 1; ack_needed = 0; after_start = 1; ptr_set = 0; byte_sh = 0;
        $display("      [slave] START");
    end
    // STOP: SCL 高时 SDA 上升
    always @(posedge sda) if (scl) begin
        n = 0; recv = 1; ack_needed = 0;
        $display("      [slave] STOP");
    end

    task classify;
        begin
            if (after_start) begin
                after_start = 0;
                if (byte_sh[7:1] == ADDR) begin
                    rw = byte_sh[0];
                    ack_needed = 1;
                    if (rw) begin
                        recv = 1;          // 先 ACK 地址
                        $display("      [slave] addr R, ptr=%02x -> data %02x", ptr, mem[ptr]);
                    end else begin
                        recv = 1;
                        $display("      [slave] addr W");
                    end
                end else begin
                    $display("      [slave] addr mismatch %02x", byte_sh);
                end
            end else if (!rw) begin
                if (!ptr_set) begin ptr = byte_sh; ptr_set = 1; $display("      [slave] ptr=%02x", ptr); end
                else begin mem[ptr] = byte_sh; $display("      [slave] mem[%02x]=%02x", ptr, byte_sh); ptr = ptr + 1; end
                ack_needed = 1;
            end
        end
    endtask

    // SCL 下降沿：准备输出
    always @(negedge scl) begin
        if (recv) begin
            if (ack_needed) begin sda_oe = 1; sda_out = 0; end
            else sda_oe = 0;
        end else begin
            if (n < 8) begin sda_oe = 1; sda_out = byte_sh[7-n]; end
            else sda_oe = 0;
        end
    end

    // SCL 上升沿：采样/推进
    always @(posedge scl) begin
        if (recv) begin
            if (n < 8) begin
                byte_sh = {byte_sh[6:0], sda_in};
                n = n + 1;
                if (n == 8) classify();
            end else begin
                n = 0; ack_needed = 0;
                if (rw) begin
                    recv = 0;                       // 地址 ACK 完成, 转入读数据
                    byte_sh = mem[ptr];
                    $display("      [slave] read data start: %02x", byte_sh);
                end
            end
        end else begin
            if (n < 8) begin
                n = n + 1;
            end else begin
                // n==8: 主机 ACK
                if (sda_in == 1'b0) begin
                    ptr = ptr + 1; byte_sh = mem[ptr]; n = 0;
                    $display("      [slave] rd ACK -> next %02x", byte_sh);
                end else begin
                    recv = 1; n = 0; after_start = 1;
                    $display("      [slave] rd NACK -> stop");
                end
            end
        end
    end
endmodule

`default_nettype wire
