
`timescale 1ns/1ps

module forwarding_tb;

    reg [4:0] rs1_ex, rs2_ex;
    reg [4:0] rd_mem, rd_wb;
    reg reg_write_mem, reg_write_wb;

    wire [1:0] forward_a, forward_b;

    forwarding_unit dut (
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .rd_mem(rd_mem),
        .reg_write_mem(reg_write_mem),
        .rd_wb(rd_wb),
        .reg_write_wb(reg_write_wb),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    task check_forwarding;
        input [1:0] expected_a;
        input [1:0] expected_b;
        input [255:0] label_text;
        begin
            #1;
            if (forward_a !== expected_a ||
                forward_b !== expected_b) begin
                $display("FAIL: %0s", label_text);
                $display("  forward_a=%b expected=%b",
                         forward_a, expected_a);
                $display("  forward_b=%b expected=%b",
                         forward_b, expected_b);
                $fatal(1);
            end
            $display("PASS: %0s", label_text);
        end
    endtask

    initial begin
        // No matching destination registers.
        rs1_ex = 5'd1; rs2_ex = 5'd2;
        rd_mem = 5'd3; rd_wb = 5'd4;
        reg_write_mem = 1'b1; reg_write_wb = 1'b1;
        check_forwarding(2'b00, 2'b00, "No forwarding");

        // EX/MEM forwards to both source operands.
        rs1_ex = 5'd5; rs2_ex = 5'd6;
        rd_mem = 5'd5; rd_wb = 5'd6;
        check_forwarding(2'b10, 2'b01, "MEM to A, WB to B");

        // Both sources match the EX/MEM destination.
        rs1_ex = 5'd7; rs2_ex = 5'd7;
        rd_mem = 5'd7; rd_wb = 5'd7;
        check_forwarding(2'b10, 2'b10, "MEM priority for both sources");

        // A newer EX/MEM match must override an older WB match.
        rs1_ex = 5'd8; rs2_ex = 5'd9;
        rd_mem = 5'd8; rd_wb = 5'd8;
        check_forwarding(2'b10, 2'b00, "MEM overrides WB for A");

        // WB forwarding when MEM does not match.
        rs1_ex = 5'd10; rs2_ex = 5'd11;
        rd_mem = 5'd12; rd_wb = 5'd10;
        check_forwarding(2'b01, 2'b00, "WB forwards to A");

        // Never forward a write to x0.
        rs1_ex = 5'd0; rs2_ex = 5'd0;
        rd_mem = 5'd0; rd_wb = 5'd0;
        check_forwarding(2'b00, 2'b00, "Ignore x0 destinations");

        // A disabled register write must not forward.
        rs1_ex = 5'd13; rs2_ex = 5'd14;
        rd_mem = 5'd13; rd_wb = 5'd14;
        reg_write_mem = 1'b0; reg_write_wb = 1'b0;
        check_forwarding(2'b00, 2'b00, "Disabled writes do not forward");

        $display("PASS: forwarding unit tests completed.");
        $finish;
    end

endmodule
