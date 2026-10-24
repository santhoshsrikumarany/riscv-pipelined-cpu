#!/usr/bin/env bash
set -euo pipefail

mkdir -p build

echo "======================================"
echo " RISC-V Pipelined CPU Test Suite"
echo "======================================"

echo
echo "[1/4] Decoder tests"
iverilog -g2012 -s decoder_tb \
    -o build/decoder_sim rtl/cpu.v tb/decoder_tb.sv
vvp build/decoder_sim

echo
echo "[2/4] Forwarding unit tests"
iverilog -g2012 -s forwarding_tb \
    -o build/forwarding_sim rtl/cpu.v tb/forwarding_tb.sv
vvp build/forwarding_sim

echo
echo "[3/4] Hazard detection tests"
iverilog -g2012 -s hazard_detection_tb \
    -o build/hazard_sim rtl/cpu.v tb/hazard_detection_tb.sv
vvp build/hazard_sim

echo
echo "[4/4] Integrated CPU tests"
iverilog -g2012 -s cpu_top_tb \
    -o build/cpu_sim rtl/cpu.v tb/testbench.sv
vvp build/cpu_sim

echo
echo "======================================"
echo " ALL TEST SUITES PASSED"
echo "======================================"
