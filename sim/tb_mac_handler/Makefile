# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/mac_handler.vhd
SRC += $(FPGA_UTILITIES_SRC_DIR)/axip_fifo_sync.vhd
SRC += $(FPGA_UTILITIES_SRC_DIR)/axis_fifo_sync.vhd
SRC += $(FPGA_UTILITIES_SRC_DIR)/axis_insert_fixed_header.vhd
SRC += $(FPGA_UTILITIES_SRC_DIR)/axis_remove_fixed_header.vhd

# List of test specific simulation files
SRC += tb_mac_handler.vhd
SRC += $(FPGA_UTILITIES_SIM_SRC_DIR)/axip_logger.vhd
SRC += $(FPGA_UTILITIES_SIM_SRC_DIR)/axip_sim.vhd
SRC += $(FPGA_UTILITIES_SIM_SRC_DIR)/lfsr.vhd
SRC += $(FPGA_UTILITIES_SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = mac_handler

# Test duration
STOP_TIME = 50us

# Test specific generics
GENERIC += -gG_BYTES=20
GENERIC += -gG_MIN_LENGTH=14
GENERIC += -gG_MAX_LENGTH=100
GENERIC += -gG_CNT_SIZE=14
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_SHOW_PACKETS=false

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

