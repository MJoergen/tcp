# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of test specific simulation files
SRC += tb_top.vhd
SRC += $(EXAMPLE_SRC_DIR)/clk_rst.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/keyboard/kb_matrix_ram.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/keyboard/m2m_keyb.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/keyboard/matrix_to_keynum.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/keyboard/mega65kbd_to_matrix.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga/font.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga/video_chars.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga/video_modes_pkg.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga/video_sync.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga_wrapper.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/eth/eth_rmii.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/eth/eth_fifo.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/eth/eth_wrapper.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/uart_serdes.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/axi_dropper.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/axi_fifo_sync.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/tdp_ram.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65_wrapper.vhd
SRC += $(EXAMPLE_SRC_DIR)/byte2wide.vhd
SRC += $(EXAMPLE_SRC_DIR)/wide2byte.vhd
SRC += $(EXAMPLE_SRC_DIR)/design.vhd
SRC += $(EXAMPLE_SRC_DIR)/top.vhd

SRC += $(SRC_DIR)/axi_pipe_flexible.vhd
SRC += $(SRC_DIR)/mac_wrapper.vhd

# Top level entity
DUT = top

# Test duration
STOP_TIME = 30us

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

