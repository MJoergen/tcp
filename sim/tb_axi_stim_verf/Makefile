# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of test specific simulation files
SRC += tb_axi_stim_verf.vhd
SRC += $(SIM_SRC_DIR)/axi_stim_verf.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axi_fifo_sync.vhd
SRC += $(SIM_SRC_DIR)/data_logger.vhd

# Top level entity
DUT = axi_stim_verf

# Test duration
STOP_TIME = 20us

# Test specific generics
GENERIC += -gG_DEBUG=false
GENERIC += -gG_SHOW_PACKETS=false
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_MAX_LENGTH=40
GENERIC += -gG_CNT_SIZE=12

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

