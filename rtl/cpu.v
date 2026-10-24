`timescale 1ns/1ps

// Register file: two combinational reads, one synchronous write.
// Read-through on a same-cycle WB write avoids stale values at ID/EX capture.
module regf (
    input wire clk,
    input wire reg_write,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] write,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);
    reg [31:0] register [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            register[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (reg_write && (rd != 5'd0))
            register[rd] <= write;
    end

    assign read_data1 = (rs1 == 5'd0) ? 32'b0 :
                        ((reg_write && (rd == rs1) && (rd != 5'd0)) ? write : register[rs1]);
    assign read_data2 = (rs2 == 5'd0) ? 32'b0 :
                        ((reg_write && (rd == rs2) && (rd != 5'd0)) ? write : register[rs2]);
endmodule

module img (
    input wire [31:0] instruction,
    output reg [31:0] immediate
);
    wire [6:0] opcode = instruction[6:0];
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011: // I-type: ADDI, LW
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            7'b0100011: // S-type: SW
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            7'b1100011: // B-type: BEQ
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                             instruction[30:25], instruction[11:8], 1'b0};
            default: immediate = 32'b0;
        endcase
    end
endmodule

module cu (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    output reg reg_write,
    output reg alu_src,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg branch,
    output reg [1:0] alu_op,
    output reg instruction_valid
);
    always @(*) begin
        reg_write = 1'b0;
        alu_src = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        alu_op = 2'b00;
        instruction_valid = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                case ({funct7, funct3})
                    10'b0000000_000, // ADD
                    10'b0100000_000, // SUB
                    10'b0000000_111, // AND
                    10'b0000000_110: begin // OR
                        instruction_valid = 1'b1;
                        reg_write = 1'b1;
                        alu_src = 1'b0;
                        alu_op = 2'b10;
                    end
                    default: begin end
                endcase
            end

            7'b0010011: begin // ADDI only
                if (funct3 == 3'b000) begin
                    instruction_valid = 1'b1;
                    reg_write = 1'b1;
                    alu_src = 1'b1;
                    alu_op = 2'b00;
                end
            end

            7'b0000011: begin // LW only
                if (funct3 == 3'b010) begin
                    instruction_valid = 1'b1;
                    reg_write = 1'b1;
                    alu_src = 1'b1;
                    mem_read = 1'b1;
                    mem_to_reg = 1'b1;
                    alu_op = 2'b00;
                end
            end

            7'b0100011: begin // SW only
                if (funct3 == 3'b010) begin
                    instruction_valid = 1'b1;
                    alu_src = 1'b1;
                    mem_write = 1'b1;
                    alu_op = 2'b00;
                end
            end

            7'b1100011: begin // BEQ
    // Bits [31:25] are part of the branch immediate, not funct7.
    if (funct3 == 3'b000) begin
        instruction_valid = 1'b1;
        branch = 1'b1;
        alu_src = 1'b0;
        alu_op = 2'b01;
    end
end

            default: begin end
        endcase
    end
endmodule

module alu_cu (
    input wire [1:0] alu_op,
    input wire [2:0] func3,
    input wire [6:0] func7,
    output reg [3:0] alu_control
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control = 4'b0000; // ADD/address calculation
            2'b01: alu_control = 4'b0001; // SUB for BEQ
            2'b10: begin
                case ({func7, func3})
                    10'b0000000_000: alu_control = 4'b0000; // ADD
                    10'b0100000_000: alu_control = 4'b0001; // SUB
                    10'b0000000_111: alu_control = 4'b0010; // AND
                    10'b0000000_110: alu_control = 4'b0011; // OR
                    default: alu_control = 4'b0000;
                endcase
            end
            default: alu_control = 4'b0000;
        endcase
    end
endmodule

module alu (
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] alu_control,
    output reg [31:0] result,
    output wire zero
);
    always @(*) begin
        case (alu_control)
            4'b0000: result = A + B;
            4'b0001: result = A - B;
            4'b0010: result = A & B;
            4'b0011: result = A | B;
            default: result = 32'b0;
        endcase
    end
    assign zero = (result == 32'b0);
endmodule

// Word-addressed data memory; byte address bits [31:2] select a 32-bit word.
module mem (
    input wire clk,
    input wire [31:0] address,
    input wire [31:0] write,
    input wire mem_read,
    input wire mem_write,
    output reg [31:0] read
);
    reg [31:0] memory [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 32'b0;
    end
    always @(*) begin
        if (mem_read) read = memory[address[31:2]];
        else read = 32'b0;
    end
    always @(posedge clk) begin
        if (mem_write) memory[address[31:2]] <= write;
    end
endmodule

module if_id_reg (
    input wire clk, input wire reset, input wire if_id_write, input wire flush,
    input wire [31:0] pc_in, input wire [31:0] instruction_in, input wire [31:0] pc_plus_4_in,
    output reg [31:0] pc_out, output reg [31:0] instruction_out, output reg [31:0] pc_plus_4_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            pc_out <= 32'b0;
            instruction_out <= 32'h00000013; // NOP
            pc_plus_4_out <= 32'b0;
        end else if (if_id_write) begin
            pc_out <= pc_in;
            instruction_out <= instruction_in;
            pc_plus_4_out <= pc_plus_4_in;
        end
    end
endmodule

module id_ex_reg (
    input wire clk, input wire reset, input wire flush,
    input wire [31:0] pc_in, input wire [31:0] read_data1_in, input wire [31:0] read_data2_in,
    input wire [31:0] immediate_in,
    input wire [4:0] rs1_in, input wire [4:0] rs2_in, input wire [4:0] rd_in,
    input wire [2:0] funct3_in, input wire [6:0] funct7_in,
    input wire reg_write_in, input wire alu_src_in, input wire mem_read_in,
    input wire mem_write_in, input wire mem_to_reg_in, input wire branch_in, input wire [1:0] alu_op_in,
    output reg [31:0] pc_out, output reg [31:0] read_data1_out, output reg [31:0] read_data2_out,
    output reg [31:0] immediate_out,
    output reg [4:0] rs1_out, output reg [4:0] rs2_out, output reg [4:0] rd_out,
    output reg [2:0] funct3_out, output reg [6:0] funct7_out,
    output reg reg_write_out, output reg alu_src_out, output reg mem_read_out,
    output reg mem_write_out, output reg mem_to_reg_out, output reg branch_out, output reg [1:0] alu_op_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            pc_out <= 0; read_data1_out <= 0; read_data2_out <= 0; immediate_out <= 0;
            rs1_out <= 0; rs2_out <= 0; rd_out <= 0; funct3_out <= 0; funct7_out <= 0;
            reg_write_out <= 0; alu_src_out <= 0; mem_read_out <= 0; mem_write_out <= 0;
            mem_to_reg_out <= 0; branch_out <= 0; alu_op_out <= 0;
        end else begin
            pc_out <= pc_in; read_data1_out <= read_data1_in; read_data2_out <= read_data2_in;
            immediate_out <= immediate_in; rs1_out <= rs1_in; rs2_out <= rs2_in; rd_out <= rd_in;
            funct3_out <= funct3_in; funct7_out <= funct7_in;
            reg_write_out <= reg_write_in; alu_src_out <= alu_src_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
            branch_out <= branch_in; alu_op_out <= alu_op_in;
        end
    end
endmodule

module ex_mem_reg (
    input wire clk, input wire reset,
    input wire [31:0] alu_result_in, input wire [31:0] read_data2_in, input wire alu_zero_in,
    input wire [4:0] rd_in,
    input wire reg_write_in, input wire mem_read_in, input wire mem_write_in, input wire mem_to_reg_in,
    output reg [31:0] alu_result_out, output reg [31:0] read_data2_out, output reg alu_zero_out,
    output reg [4:0] rd_out,
    output reg reg_write_out, output reg mem_read_out, output reg mem_write_out, output reg mem_to_reg_out
);
    always @(posedge clk) begin
        if (reset) begin
            alu_result_out <= 0; read_data2_out <= 0; alu_zero_out <= 0; rd_out <= 0;
            reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0; mem_to_reg_out <= 0;
        end else begin
            alu_result_out <= alu_result_in; read_data2_out <= read_data2_in; alu_zero_out <= alu_zero_in;
            rd_out <= rd_in; reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule

module mem_wb_reg (
    input wire clk, input wire reset,
    input wire [31:0] alu_result_in, input wire [31:0] memory_data_in, input wire [4:0] rd_in,
    input wire reg_write_in, input wire mem_to_reg_in,
    output reg [31:0] alu_result_out, output reg [31:0] memory_data_out, output reg [4:0] rd_out,
    output reg reg_write_out, output reg mem_to_reg_out
);
    always @(posedge clk) begin
        if (reset) begin
            alu_result_out <= 0; memory_data_out <= 0; rd_out <= 0;
            reg_write_out <= 0; mem_to_reg_out <= 0;
        end else begin
            alu_result_out <= alu_result_in; memory_data_out <= memory_data_in; rd_out <= rd_in;
            reg_write_out <= reg_write_in; mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule

module forwarding_unit (
    input wire [4:0] rs1_ex, input wire [4:0] rs2_ex,
    input wire [4:0] rd_mem, input wire reg_write_mem,
    input wire [4:0] rd_wb, input wire reg_write_wb,
    output reg [1:0] forward_a, output reg [1:0] forward_b
);
    always @(*) begin
        forward_a = 2'b00; forward_b = 2'b00;
        if (reg_write_mem && (rd_mem != 0) && (rd_mem == rs1_ex)) forward_a = 2'b10;
        else if (reg_write_wb && (rd_wb != 0) && (rd_wb == rs1_ex)) forward_a = 2'b01;
        if (reg_write_mem && (rd_mem != 0) && (rd_mem == rs2_ex)) forward_b = 2'b10;
        else if (reg_write_wb && (rd_wb != 0) && (rd_wb == rs2_ex)) forward_b = 2'b01;
    end
endmodule

module hazard_detection_unit (
    input wire [4:0] rs1_id, input wire [4:0] rs2_id,
    input wire uses_rs1_id, input wire uses_rs2_id,
    input wire [4:0] rd_ex, input wire mem_read_ex,
    output reg pc_write, output reg if_id_write, output reg control_stall
);
    always @(*) begin
        pc_write = 1'b1; if_id_write = 1'b1; control_stall = 1'b0;
        if (mem_read_ex && (rd_ex != 0) &&
            ((uses_rs1_id && (rd_ex == rs1_id)) || (uses_rs2_id && (rd_ex == rs2_id)))) begin
            pc_write = 1'b0; if_id_write = 1'b0; control_stall = 1'b1;
        end
    end
endmodule

`timescale 1ns/1ps

// Five-stage pipelined RV32I subset CPU.
// Supported instructions: ADD, SUB, AND, OR, ADDI, LW, SW, BEQ.
// Instruction memory is initialized to NOPs; a testbench may preload
// dut.instruction_memory[index] with machine-code words.
module cpu_top (
    input wire clk,
    input wire reset
);
    // ---------------- IF: program counter and instruction memory ----------------
    reg [31:0] pc_current;
    wire [31:0] pc_plus_4 = pc_current + 32'd4;
    wire [31:0] next_pc;
    wire [31:0] instruction;

    reg [31:0] instruction_memory [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            instruction_memory[i] = 32'h00000013; // ADDI x0,x0,0 (NOP)
    end
    assign instruction = instruction_memory[pc_current[31:2]];

    // ---------------- Shared hazard and branch control ----------------
    wire pc_write;
    wire if_id_write;
    wire control_stall;
    wire flush;
    wire take_branch;

    // ---------------- IF/ID pipeline register ----------------
    wire [31:0] pc_id;
    wire [31:0] instruction_id;
    wire [31:0] pc_plus_4_id;

    if_id_reg if_id (
        .clk(clk), .reset(reset), .if_id_write(if_id_write), .flush(flush),
        .pc_in(pc_current), .instruction_in(instruction), .pc_plus_4_in(pc_plus_4),
        .pc_out(pc_id), .instruction_out(instruction_id), .pc_plus_4_out(pc_plus_4_id)
    );

    // ---------------- ID: decode instruction fields ----------------
    wire [6:0] opcode_id = instruction_id[6:0];
    wire [4:0] rd_id = instruction_id[11:7];
    wire [2:0] funct3_id = instruction_id[14:12];
    wire [4:0] rs1_id = instruction_id[19:15];
    wire [4:0] rs2_id = instruction_id[24:20];
    wire [6:0] funct7_id = instruction_id[31:25];

    // ---------------- Register file and writeback bus ----------------
    wire [31:0] read_data1_id;
    wire [31:0] read_data2_id;
    wire [4:0] rd_wb;
    wire reg_write_wb;
    wire mem_to_reg_wb;
    wire [31:0] write_back_data;

    regf reg_file (
        .clk(clk), .reg_write(reg_write_wb), .rs1(rs1_id), .rs2(rs2_id),
        .rd(rd_wb), .write(write_back_data),
        .read_data1(read_data1_id), .read_data2(read_data2_id)
    );

    // ---------------- Immediate generator and main control ----------------
   wire [31:0] immediate_id;
img immediate_generator (
    .instruction(instruction_id),
    .immediate(immediate_id)
);

wire reg_write_id, alu_src_id, mem_read_id;
wire mem_write_id, mem_to_reg_id, branch_id;
wire [1:0] alu_op_id;
wire instruction_valid_id;

cu control_unit (
    .opcode(opcode_id),
    .funct3(funct3_id),
    .funct7(funct7_id),
    .reg_write(reg_write_id),
    .alu_src(alu_src_id),
    .mem_read(mem_read_id),
    .mem_write(mem_write_id),
    .mem_to_reg(mem_to_reg_id),
    .branch(branch_id),
    .alu_op(alu_op_id),
    .instruction_valid(instruction_valid_id)
);

    // Identify real source operands to avoid false load-use stalls.
    // Identify source operands only for supported instructions.
wire uses_rs1_id = instruction_valid_id &&
                   ((opcode_id == 7'b0110011) ||
                    (opcode_id == 7'b0010011) ||
                    (opcode_id == 7'b0000011) ||
                    (opcode_id == 7'b0100011) ||
                    (opcode_id == 7'b1100011));

wire uses_rs2_id = instruction_valid_id &&
                   ((opcode_id == 7'b0110011) ||
                    (opcode_id == 7'b0100011) ||
                    (opcode_id == 7'b1100011));

    // ---------------- Load-use hazard detection ----------------
    wire [4:0] rd_ex;
    wire mem_read_ex;
    hazard_detection_unit hazard_unit (
        .rs1_id(rs1_id), .rs2_id(rs2_id),
        .uses_rs1_id(uses_rs1_id), .uses_rs2_id(uses_rs2_id),
        .rd_ex(rd_ex), .mem_read_ex(mem_read_ex),
        .pc_write(pc_write), .if_id_write(if_id_write), .control_stall(control_stall)
    );

    // A load-use stall inserts a bubble into ID/EX by zeroing its controls.
    wire reg_write_id_final = control_stall ? 1'b0 : reg_write_id;
    wire alu_src_id_final = control_stall ? 1'b0 : alu_src_id;
    wire mem_read_id_final = control_stall ? 1'b0 : mem_read_id;
    wire mem_write_id_final = control_stall ? 1'b0 : mem_write_id;
    wire mem_to_reg_id_final = control_stall ? 1'b0 : mem_to_reg_id;
    wire branch_id_final = control_stall ? 1'b0 : branch_id;
    wire [1:0] alu_op_id_final = control_stall ? 2'b00 : alu_op_id;

    // ---------------- ID/EX pipeline register ----------------
    wire [31:0] pc_ex, read_data1_ex, read_data2_ex, immediate_ex;
    wire [4:0] rs1_ex, rs2_ex;
    wire [2:0] funct3_ex;
    wire [6:0] funct7_ex;
    wire reg_write_ex, alu_src_ex, mem_write_ex, mem_to_reg_ex, branch_ex;
    wire [1:0] alu_op_ex;

    id_ex_reg id_ex (
        .clk(clk), .reset(reset), .flush(flush),
        .pc_in(pc_id), .read_data1_in(read_data1_id), .read_data2_in(read_data2_id),
        .immediate_in(immediate_id), .rs1_in(rs1_id), .rs2_in(rs2_id), .rd_in(rd_id),
        .funct3_in(funct3_id), .funct7_in(funct7_id),
        .reg_write_in(reg_write_id_final), .alu_src_in(alu_src_id_final),
        .mem_read_in(mem_read_id_final), .mem_write_in(mem_write_id_final),
        .mem_to_reg_in(mem_to_reg_id_final), .branch_in(branch_id_final), .alu_op_in(alu_op_id_final),
        .pc_out(pc_ex), .read_data1_out(read_data1_ex), .read_data2_out(read_data2_ex),
        .immediate_out(immediate_ex), .rs1_out(rs1_ex), .rs2_out(rs2_ex), .rd_out(rd_ex),
        .funct3_out(funct3_ex), .funct7_out(funct7_ex),
        .reg_write_out(reg_write_ex), .alu_src_out(alu_src_ex), .mem_read_out(mem_read_ex),
        .mem_write_out(mem_write_ex), .mem_to_reg_out(mem_to_reg_ex),
        .branch_out(branch_ex), .alu_op_out(alu_op_ex)
    );

    // ---------------- EX: forwarding and ALU operand selection ----------------
    wire [4:0] rd_mem;
    wire reg_write_mem, mem_read_mem, mem_write_mem, mem_to_reg_mem;
    wire [31:0] alu_result_mem;
    wire [1:0] forward_a, forward_b;
    wire [31:0] alu_input_a_forwarded;
    wire [31:0] alu_input_b_forwarded;
    wire [31:0] alu_input_b;
    wire [31:0] store_data_ex;

    forwarding_unit forwarding (
        .rs1_ex(rs1_ex), .rs2_ex(rs2_ex),
        .rd_mem(rd_mem), .reg_write_mem(reg_write_mem),
        .rd_wb(rd_wb), .reg_write_wb(reg_write_wb),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    assign alu_input_a_forwarded =
        (forward_a == 2'b10) ? alu_result_mem :
        (forward_a == 2'b01) ? write_back_data : read_data1_ex;

    assign alu_input_b_forwarded =
        (forward_b == 2'b10) ? alu_result_mem :
        (forward_b == 2'b01) ? write_back_data : read_data2_ex;

    // alu_src_ex=1 selects an immediate for address/immediate arithmetic.
    // Store data remains the (possibly forwarded) rs2 value, not the immediate.
    assign alu_input_b = alu_src_ex ? immediate_ex : alu_input_b_forwarded;
    assign store_data_ex = alu_input_b_forwarded;

    wire [3:0] alu_control_ex;
    alu_cu alu_control_unit (
        .alu_op(alu_op_ex), .func3(funct3_ex), .func7(funct7_ex), .alu_control(alu_control_ex)
    );

    wire [31:0] alu_result_ex;
    wire alu_zero_ex;
    alu alu_unit (
        .A(alu_input_a_forwarded), .B(alu_input_b), .alu_control(alu_control_ex),
        .result(alu_result_ex), .zero(alu_zero_ex)
    );

    // ---------------- Branch decision / flush ----------------
    wire [31:0] branch_target = pc_ex + immediate_ex;
    assign take_branch = branch_ex && alu_zero_ex;
    assign flush = take_branch;
    assign next_pc = take_branch ? branch_target : pc_plus_4;

    // ---------------- EX/MEM pipeline register ----------------
    wire [31:0] read_data2_mem;
    wire alu_zero_mem;
    ex_mem_reg ex_mem (
        .clk(clk), .reset(reset), .alu_result_in(alu_result_ex),
        .read_data2_in(store_data_ex), .alu_zero_in(alu_zero_ex), .rd_in(rd_ex),
        .reg_write_in(reg_write_ex), .mem_read_in(mem_read_ex), .mem_write_in(mem_write_ex),
        .mem_to_reg_in(mem_to_reg_ex), .alu_result_out(alu_result_mem),
        .read_data2_out(read_data2_mem), .alu_zero_out(alu_zero_mem), .rd_out(rd_mem),
        .reg_write_out(reg_write_mem), .mem_read_out(mem_read_mem),
        .mem_write_out(mem_write_mem), .mem_to_reg_out(mem_to_reg_mem)
    );

    // ---------------- MEM: data memory ----------------
    wire [31:0] memory_data_mem;
    mem data_memory (
        .clk(clk), .address(alu_result_mem), .write(read_data2_mem),
        .mem_read(mem_read_mem), .mem_write(mem_write_mem), .read(memory_data_mem)
    );

    // ---------------- MEM/WB pipeline register ----------------
    wire [31:0] alu_result_wb, memory_data_wb;
    mem_wb_reg mem_wb (
        .clk(clk), .reset(reset), .alu_result_in(alu_result_mem), .memory_data_in(memory_data_mem),
        .rd_in(rd_mem), .reg_write_in(reg_write_mem), .mem_to_reg_in(mem_to_reg_mem),
        .alu_result_out(alu_result_wb), .memory_data_out(memory_data_wb),
        .rd_out(rd_wb), .reg_write_out(reg_write_wb), .mem_to_reg_out(mem_to_reg_wb)
    );

    // ---------------- WB and PC update ----------------
    assign write_back_data = mem_to_reg_wb ? memory_data_wb : alu_result_wb;

    always @(posedge clk) begin
        if (reset) pc_current <= 32'b0;
        else if (pc_write) pc_current <= next_pc;
    end
endmodule
