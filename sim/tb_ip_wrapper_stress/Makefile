# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/ip_wrapper.vhd
SRC += $(SRC_DIR)/axi_fifo_squash.vhd
SRC += $(SRC_DIR)/axi_fifo_wide.vhd

# List of test specific simulation files
SRC += tb_ip_wrapper_stress.vhd
SRC += $(SIM_SRC_DIR)/data_logger.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axi_fifo_sync.vhd

# Top level entity
DUT = ip_wrapper_stress

# Test duration
STOP_TIME = 20us

# Test specific generics
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_RANDOM=false
GENERIC += -gG_FAST=false
GENERIC += -gG_SHOW_PACKETS=false
GENERIC += -gG_SHOW_PROTOCOL=false

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

