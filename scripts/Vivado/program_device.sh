#!/bin/sh

echo "Programming board!"
/opt/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source program_device.tcl || exit 1
