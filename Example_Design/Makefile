# List of library files
SRC_DIR = src
SRC += $(SRC_DIR)/axi_pipe_flexible.vhd
SRC += $(SRC_DIR)/ip_wrapper.vhd
SRC += $(SRC_DIR)/mac_wrapper.vhd
SRC += $(SRC_DIR)/tcp_protocol.vhd
SRC += $(SRC_DIR)/tcp_wrapper.vhd
# List of platform files
SRC += $(SRC_DIR)/mega65_wrapper.vhd
SRC += $(SRC_DIR)/mega65/font.vhd
SRC += $(SRC_DIR)/mega65/mega65kbd_to_matrix.vhd
SRC += $(SRC_DIR)/mega65/video_chars.vhd
SRC += $(SRC_DIR)/mega65/video_modes_pkg.vhd
SRC += $(SRC_DIR)/mega65/video_sync.vhd
# List of design files
SRC += $(SRC_DIR)/design.vhd

# List of Example Design files
SRC += top.vhd

# Top level entity
TOP = top

################## Don't change anything below here ******************************

# Specify install location of the AMD Vivado tool
VIVADO_DIR = /opt/Xilinx/Vivado/2024.1

PART = xc7a200tfbg484-2

XDC = $(TOP).xdc

# Generate number of seconds since epoch
G_TIMESTAMP = $(shell echo "16o $$(date +%s) p" | dc)
# Generate 32 LSB of git commit
G_COMMIT_ID = $(shell git reflog --no-abbrev-commit -1 | cut -c 1-8)

GENERICS += G_TIMESTAMP=32'h$(G_TIMESTAMP)
GENERICS += G_COMMIT_ID=32'h$(G_COMMIT_ID)

OPTIONS += -flatten_hierarchy none

# Generate the bit-file used to configure the FPGA
build/$(TOP).bit: build/$(TOP).tcl $(SRC) $(XDC)
	bash -c "source $(VIVADO_DIR)/settings64.sh ; vivado -mode tcl -source $<"

# Generate the build script used by Vivado
# This is based on:
# https://docs.amd.com/r/2024.1-English/ug892-vivado-design-flows-overview/Using-Non-Project-Mode-Tcl-Commands
build/$(TOP).tcl: Makefile
	mkdir -p build
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(SRC) }" >> $@
	echo "read_xdc { $(XDC) }" >> $@
	echo "set_property PART $(PART) [current_project]" >> $@
	echo "set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO} [current_project]" >> $@
	echo "synth_design -top $(TOP) $(OPTIONS) -generic { $(GENERICS) }" >> $@
	echo "source ../synth/debug.tcl" >> $@
	echo "opt_design" >> $@
	echo "place_design" >> $@
	echo "phys_opt_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force build/$(TOP).dcp" >> $@
	echo "write_bitstream -force build/$(TOP).bit" >> $@
	echo "exit" >> $@

.PHONY: clean
clean:
	rm -rf build
	rm -rf vivado*
	rm -rf .Xil
	rm -rf .cache
	rm -rf clockInfo.txt
	rm -rf debug.ltx

