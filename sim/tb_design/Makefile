# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the design.vhd file.

# List of test specific simulation files
SRC += tb_design.vhd
SRC += $(EXAMPLE_SRC_DIR)/clk_rst.vhd
SRC += $(EXAMPLE_SRC_DIR)/byte2wide.vhd
SRC += $(EXAMPLE_SRC_DIR)/wide2byte.vhd
SRC += $(EXAMPLE_SRC_DIR)/controller.vhd
SRC += $(EXAMPLE_SRC_DIR)/design.vhd

SRC += $(SRC_DIR)/axis_remove_fixed_header.vhd
SRC += $(SRC_DIR)/axis_insert_fixed_header.vhd
SRC += $(SRC_DIR)/mac_handler.vhd

# Top level entity
DUT = design

# Test duration
STOP_TIME = 30us

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

