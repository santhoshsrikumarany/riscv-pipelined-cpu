`timescale 1ns/1ps

module cpu_top_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    integer i;

    cpu_top dut (.clk(clk), .reset(reset));
  wire [31:0] debug_x1 = dut.reg_file.register[1];
wire [31:0] debug_x2 = dut.reg_file.register[2];
wire [31:0] debug_x3 = dut.reg_file.register[3];
wire [31:0] debug_x4 = dut.reg_file.register[4];
wire [31:0] debug_x5 = dut.reg_file.register[5];
wire [31:0] debug_x6 = dut.reg_file.register[6];
wire [31:0] debug_x7 = dut.reg_file.register[7];
wire [31:0] debug_x8 = dut.reg_file.register[8];
    always #5 clk = ~clk;
  integer stall_count = 0;
integer flush_count = 0;
integer ex_mem_forward_count = 0;
integer mem_wb_forward_count = 0;

always @(negedge clk) begin
    if (!reset) begin
        if (dut.forward_a == 2'b10 || dut.forward_b == 2'b10)
            ex_mem_forward_count = ex_mem_forward_count + 1;

        if (dut.forward_a == 2'b01 || dut.forward_b == 2'b01)
            mem_wb_forward_count = mem_wb_forward_count + 1;
    end
end
always @(posedge clk) begin
    if (!reset) begin
        if (dut.control_stall)
            stall_count <= stall_count + 1;

        if (dut.flush)
            flush_count <= flush_count + 1;
    end
end
    initial begin
        // Program:
        // addi x1,x0,5
        // addi x2,x0,7
        // add  x3,x1,x2       (forwarding)
        // sw   x3,0(x0)       (forwarded store data)
        // lw   x4,0(x0)
        // addi x5,x4,1        (load-use stall)
        // addi x6,x0,13
        // beq  x5,x6,+8       (taken; skips x7=99)
        // addi x7,x0,99       (must be flushed)
        // addi x8,x0,42
        dut.instruction_memory[0] = 32'h00500093;
        dut.instruction_memory[1] = 32'h00700113;
        dut.instruction_memory[2] = 32'h002081B3;
        dut.instruction_memory[3] = 32'h00302023;
        dut.instruction_memory[4] = 32'h00002203;
        dut.instruction_memory[5] = 32'h00120293;
        dut.instruction_memory[6] = 32'h00D00313;
        dut.instruction_memory[7] = 32'h00628463;
        dut.instruction_memory[8] = 32'h06300393;
        dut.instruction_memory[9] = 32'h02A00413;

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;

        repeat (30) @(posedge clk);
        #1;

        $display("x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x6=%0d x7=%0d x8=%0d mem[0]=%0d",
                 dut.reg_file.register[1], dut.reg_file.register[2],
                 dut.reg_file.register[3], dut.reg_file.register[4],
                 dut.reg_file.register[5], dut.reg_file.register[6],
                 dut.reg_file.register[7], dut.reg_file.register[8],
                 dut.data_memory.memory[0]);

        if (dut.reg_file.register[1] !== 32'd5) $fatal(1, "FAIL: x1 expected 5");
        if (dut.reg_file.register[2] !== 32'd7) $fatal(1, "FAIL: x2 expected 7");
        if (dut.reg_file.register[3] !== 32'd12) $fatal(1, "FAIL: x3 expected 12 (ALU forwarding)");
        if (dut.data_memory.memory[0] !== 32'd12) $fatal(1, "FAIL: memory[0] expected 12 (store-data forwarding)");
        if (dut.reg_file.register[4] !== 32'd12) $fatal(1, "FAIL: x4 expected 12 (LW)");
        if (dut.reg_file.register[5] !== 32'd13) $fatal(1, "FAIL: x5 expected 13 (load-use handling)");
        if (dut.reg_file.register[6] !== 32'd13) $fatal(1, "FAIL: x6 expected 13");
        if (dut.reg_file.register[7] !== 32'd0) $fatal(1, "FAIL: x7 should remain 0 (branch flush)");
        if (dut.reg_file.register[8] !== 32'd42) $fatal(1, "FAIL: x8 expected 42 (branch target)");
if (stall_count == 0)
    $fatal(1, "FAIL: load-use stall was never detected");

if (flush_count == 0)
    $fatal(1, "FAIL: branch flush was never detected");

if (ex_mem_forward_count == 0)
    $fatal(1, "FAIL: EX/MEM forwarding was never exercised");

if (mem_wb_forward_count == 0)
    $fatal(1, "FAIL: MEM/WB forwarding was never exercised");

$display("EX/MEM forwarding observations: %0d", ex_mem_forward_count);
$display("MEM/WB forwarding observations: %0d", mem_wb_forward_count);
$display("Stall cycles observed: %0d", stall_count);
$display("Flush cycles observed: %0d", flush_count);
        $display("PASS: arithmetic, forwarding, SW/LW, load-use stall, and taken-branch flush verified.");
        $finish;
    end

    initial begin
        $dumpfile("cpu_top.vcd");
        $dumpvars(0, cpu_top_tb);
    end
endmodule
