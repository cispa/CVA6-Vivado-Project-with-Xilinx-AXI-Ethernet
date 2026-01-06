# CVA6 RISC-V CPU and SoC - Vivado Project and Software Stack

## Overview
This repository contains (scripts generating) a Vivado 2024.2 project built around the [CVA6 RISC-V CPU](https://github.com/openhwgroup/cva6) and a [software stack](https://github.com/pulp-platform/cva6-sdk) including u-boot and embedded linux.
This project currently only supports the Digilent Genesys2 board.

## Hardware Stack

Currently, the SoC contains the following devices:
- the cva6 CPU in 64-bit configuration with SV39 MMU @50MHz
- HPDCache in write-back mode with support for Zicbom instructions (cache clean/invalidate/flush)
- CLINT (core-local interrupt controller) and PLIC (platform-level interrupt controller)
- UART console, mapped to the USB UART 
- Xilinx SPI, configured for booting from the connected SD card
- [Xilinx AXI Ethernet Subsystem](https://www.xilinx.com/products/intellectual-property/axi_ethernet.html) including a DMA. Please note that you need to purchase a license from Xilinx for the underlying IP core.
- boot ROM for the cva6
- I2C controller for the audio IC on the Genesys2
- a Pmod GPIO controller
- DDR3 memory controller

## Software Stack
The software stack contains:
- a boot ROM which loads a bootloader from the on-board SD card
- OpenSBI, which implements the SBI interface for the operating system that we will be running in S-Mode (Linux)
- u-boot, the boot loader for Linux; configured to default to loading Linux via tftp, but with support for booting linux from SD card as well
- embedded Linux based on buildroot, with kernel 5.10.7

## Running the image

Run the following steps in-order to execute the project.
This assumes Xilinx Vivado to installed in `/opt/Xilinx/Vivado/2024.2/` (you can create a corresponding symlink).

### Compiling hardware and software stacks

First, be sure to update the project submodules:
```bash
    git submodule update --init --recursive
```

After that, use the "all" target of the top-level makefile to compile hardware and software:
```bash
    make all # use "fpga" to only compile the FPGA target and "images" to only compile software
```

### Preparing the SD card for the software stack
Currently, the bootrom is configured to load a bootloader from the on-board SD card reader.
To this end, you need to program an SD card with the OpenSBI and u-boot images.
The SD card uses GUID partitioning, with one partition containing the OpenSBI image and u-boot and a FAT-32 partition containing Linux and its RAM file system.
The top-level Makefile contains a target for creating the SD card:

```bash
    sudo -E make flash-sdcard SDDEVICE=/dev/sdxxx # double-check device!
```

### Preparing the TFTP server for TFTP booting
There is a convenience script in the software stack for launching a TFTP server:
```bash
    cd software/include/cva6-sdk/scripts
    sudo INTERFACE=ethXXX ./start-tftp.sh
```

### Programming the FPGA via JTAG
The top-level make file contains a target for programming the FPGA via JTAG:
```bash
    make program-device
```
This assumes proper installation of Vivado drivers; see the Vivado installation manual.
Make sure the SD card is inserted **before attempting to program**.

### Connecting to the Console and Booting
You can use your favorite console emulator, e.g., picocom, to connect to the board:

```bash
    picocom -b 115200 /dev/serial/by-id/usb-XXXX
```
If you do not do anything, the board will do a TFTP boot assuming you have started the TFTP server.
Abort the boot via TFTP by pressing any button during the u-boot countdown and use the following u-boot command to boot Linux from the SD card instead:
```bash
    mmc info; fatload mmc 0:2 90000000 uImage; setenv fdt_high 0xffffffffffffffff; bootm 90000000 - $(fdtcontroladdr)
```

After boot is complete, use the convenience script to log into the FPGA via TFTP:
```bash
    cd software/include/cva6-sdk/scripts
    ./ssh.sh
```

## Making Modifications - Hardware
After generating your first bitstream, you can open the Vivado project in GUI mode using the provided script:
```bash
    cd scripts/Vivado
    ./open_project.sh
```
This allows you to, e.g., add additional AXI peripherals from the Xilinx or Digilent IP catalogs, to add hardware debug cores ([ILAs](https://www.xilinx.com/products/intellectual-property/ila.html) or [System ILAs](https://www.xilinx.com/products/intellectual-property/system-ila.html)), navigate the synthesized and implemented design, etc.
You can find the SoC in the block design ("Open Block Design" on the left).
When you want to commit modifications to the Soc, select File->Project->Write TCL and store the resulting file in a temporary directory. Open the file, copy the `cr_bd_SoC` method in its entirety and replace the method in the `scripts/Vivado/create_bd.tcl` script.

*Note that the Vivado project including any modifications to the SoC is deleted by the `make fpga` target if you do not overwrite `create_bd.tcl`.*
Source code modifications *should* be picked up by Vivado; if you are unsure, run `make fpga` to re-create the project.

## Making Modifications - Software
Go through the Makefile and the top-level directories in the software project to get an understanding of what happens where.
The easiest way to make small modifications is to add patches, e.g., similar to the patches for Linux in `linux_patch` and to the patches for u-boot and OpenSBI in `xlnx_patch`. Linux patches are pulled in by buildroot automatically. For new xlnx_patches, add corresponding targets in the top-level makefile.

## Changes to upstream CVA6 project
Hardware
- CVA6 has support for additional boards, such as the Nexys Video.
- CVA6 does not use a Vivado project and the IP integrator, but instead provides custom scripts for synthesizing IP cores and configures the SoC in SystemVerilog as well.
- This fork of CVA6 adds support for Xilinx Ethernet in the Device Tree contained in the Boot ROM.

Software
- The TFTP boot for u-boot is unique to this fork.
- The build generates an SSH key during each compile and embeds it into the authorized_keys file for the root user in the embedded Linux FS. The convenience script automatically loads the key with SSH.
- This Linux configuration uses the SBI console during early boot and loads the full 16550 UART driver for interfacing with the console later on.
