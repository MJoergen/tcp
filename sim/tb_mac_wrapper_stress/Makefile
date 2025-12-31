# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/mac_wrapper.vhd
SRC += $(SRC_DIR)/axis_insert_fixed_header.vhd
SRC += $(SRC_DIR)/axis_remove_fixed_header.vhd

# List of test specific simulation files
SRC += tb_mac_wrapper_stress.vhd
SRC += $(SIM_SRC_DIR)/data_logger.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axi_fifo_sync.vhd
SRC += $(SIM_SRC_DIR)/axi_stim_verf.vhd

# Top level entity
DUT = mac_wrapper_stress

# Test duration
STOP_TIME = 50us

# Test specific generics
GENERIC += -gG_BYTES=20
GENERIC += -gG_MIN_LENGTH=14
GENERIC += -gG_MAX_LENGTH=100
GENERIC += -gG_CNT_SIZE=14
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_SHOW_PACKETS=true

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

