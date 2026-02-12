#!/usr/bin/env bash
set -e

# Clean previous GHDL work library
rm -f work-obj*.cf

# Source files / top entity
SRC1="mac.vhd"
SRC2="tb_mac.vhd"

TOP="tb_mac"
STD="08"
VCD="mac_sim.vcd"
STOP="200ns"

# Analyze sources with VHDL standard (package first!)
ghdl -a --std="$STD" "$SRC1"
ghdl -a --std="$STD" "$SRC2"

# Elaborate top
ghdl -e --std="$STD" "$TOP"

# Run simulation and write VCD
ghdl -r --std="$STD" "$TOP" --stop-time="$STOP" --vcd="$VCD"

echo "MAC Simulation complete. VCD: $VCD"
