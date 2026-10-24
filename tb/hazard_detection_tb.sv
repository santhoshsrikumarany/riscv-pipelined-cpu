`timescale 1ns/1ps

module hazard_detection_tb;
    reg [4:0] rs1_id, rs2_id, rd_ex;
    reg uses_rs1_id, uses_rs2_id, mem_read_ex;

    wire pc_write, if_id_write, control_stall;

    hazard_detection_unit dut (
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .uses_rs1_id(uses_rs1_id),
        .uses_rs2_id(uses_rs2_id),
        .rd_ex(rd_ex),
        .mem_read_ex(mem_read_ex),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .control_stall(control_stall)
    );

    task check_hazard;
        input expected_stall;
        input string test_name;
        begin
            #1;
            if (control_stall !== expected_stall ||
                pc_write !== !expected_stall ||
                if_id_write !== !expected_stall) begin
                $display("FAIL: %s", test_name);
                $display("stall=%b pc_write=%b if_id_write=%b",
                         control_stall, pc_write, if_id_write);
                $fatal(1);
            end
            $display("PASS: %s", test_name);
        end
    endtask

    initial begin
        // Load-use dependency through rs1 must stall.
        rs1_id = 5; rs2_id = 6; rd_ex = 5;
        uses_rs1_id = 1; uses_rs2_id = 1; mem_read_ex = 1;
        check_hazard(1, "Load-use dependency on rs1");

        // Load-use dependency through rs2 must stall.
        rs1_id = 6; rs2_id = 5; rd_ex = 5;
        uses_rs1_id = 1; uses_rs2_id = 1; mem_read_ex = 1;
        check_hazard(1, "Load-use dependency on rs2");

        // A matching but unused rs2 must not stall.
        rs1_id = 6; rs2_id = 5; rd_ex = 5;
        uses_rs1_id = 1; uses_rs2_id = 0; mem_read_ex = 1;
        check_hazard(0, "Unused rs2 does not cause a stall");

        // No destination-register match must not stall.
        rs1_id = 1; rs2_id = 2; rd_ex = 5;
        uses_rs1_id = 1; uses_rs2_id = 1; mem_read_ex = 1;
        check_hazard(0, "No dependency");

        // Loads targeting x0 must not stall.
        rs1_id = 0; rs2_id = 0; rd_ex = 0;
        uses_rs1_id = 1; uses_rs2_id = 1; mem_read_ex = 1;
        check_hazard(0, "Destination x0 does not cause a stall");

        // A non-load instruction must not trigger this load-use detector.
        rs1_id = 5; rs2_id = 6; rd_ex = 5;
        uses_rs1_id = 1; uses_rs2_id = 1; mem_read_ex = 0;
        check_hazard(0, "No stall when EX instruction is not a load");

        $display("PASS: all hazard detection tests completed.");
        $finish;
    end
endmodule