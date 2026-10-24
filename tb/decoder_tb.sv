`timescale 1ns/1ps

module decoder_tb;

    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;

    wire reg_write;
    wire alu_src;
    wire mem_read;
    wire mem_write;
    wire mem_to_reg;
    wire branch;
    wire [1:0] alu_op;
    wire instruction_valid;

    cu dut (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .alu_op(alu_op),
        .instruction_valid(instruction_valid)
    );

    task check_invalid;
        input [6:0] op;
        input [2:0] f3;
        input [6:0] f7;
        begin
            opcode = op;
            funct3 = f3;
            funct7 = f7;
            #1;

            if (instruction_valid !== 1'b0 ||
                reg_write !== 1'b0 ||
                mem_read !== 1'b0 ||
                mem_write !== 1'b0 ||
                branch !== 1'b0) begin
                $display("FAIL: invalid encoding op=%b f3=%b f7=%b",
                         op, f3, f7);
                $fatal(1);
            end
        end
    endtask

    task check_valid;
        input [6:0] op;
        input [2:0] f3;
        input [6:0] f7;
        begin
            opcode = op;
            funct3 = f3;
            funct7 = f7;
            #1;

            if (instruction_valid !== 1'b1) begin
                $display("FAIL: valid encoding op=%b f3=%b f7=%b",
                         op, f3, f7);
                $fatal(1);
            end
        end
    endtask

    initial begin
        // Supported R-type instructions
        check_valid(7'b0110011, 3'b000, 7'b0000000); // ADD
        check_valid(7'b0110011, 3'b000, 7'b0100000); // SUB
        check_valid(7'b0110011, 3'b111, 7'b0000000); // AND
        check_valid(7'b0110011, 3'b110, 7'b0000000); // OR

        // Supported immediate, load, store, and branch
        check_valid(7'b0010011, 3'b000, 7'b0000000); // ADDI
        check_valid(7'b0000011, 3'b010, 7'b0000000); // LW
        check_valid(7'b0100011, 3'b010, 7'b0000000); // SW
        check_valid(7'b1100011, 3'b000, 7'b0000000); // BEQ
        check_valid(7'b1100011, 3'b000, 7'b0000001); // BEQ with nonzero immediate bits

        // Unsupported function encodings
        check_invalid(7'b0110011, 3'b001, 7'b0000000);
        check_invalid(7'b0110011, 3'b000, 7'b0000001);
        check_invalid(7'b0010011, 3'b111, 7'b0000000);
        check_invalid(7'b0000011, 3'b000, 7'b0000000);
        check_invalid(7'b0100011, 3'b001, 7'b0000000);
        check_invalid(7'b1100011, 3'b001, 7'b0000000);

        // Unsupported opcode
        check_invalid(7'b1111111, 3'b000, 7'b0000000);

        $display("PASS: decoder supported/unsupported encoding tests passed.");
        $finish;
    end

endmodule