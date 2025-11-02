# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of test specific simulation files
SRC += tb_top.vhd
SRC += $(EXAMPLE_SRC_DIR)/clk_rst.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/font.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/kb_matrix_ram.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/m2m_keyb.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/matrix_to_keynum.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/mega65kbd_to_matrix.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/uart_serdes.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/vga_wrapper.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/video_chars.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/video_modes_pkg.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65/video_sync.vhd
SRC += $(EXAMPLE_SRC_DIR)/mega65_wrapper.vhd
SRC += $(EXAMPLE_SRC_DIR)/top.vhd

# Top level entity
DUT = top

# Test duration
STOP_TIME = 30us

# Test specific generics
GENERIC += -gG_START_ZERO=false
GENERIC += -gG_DEBUG=false
GENERIC += -gG_SHOW_PACKETS=false
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_MAX_LENGTH=40
GENERIC += -gG_CNT_SIZE=12

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

