#!/bin/sh
set -e

echo "Running synthesis/implementation/bitstream generation in Vivado"
cd ../Vivado
/opt/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source create_bitstream.tcl || exit 1
