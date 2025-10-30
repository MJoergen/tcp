# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the ip_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/ip_wrapper.vhd
SRC += $(SRC_DIR)/axi_pipe_flexible.vhd

# List of test specific simulation files
SRC += tb_ip_wrapper_stress.vhd
SRC += $(SIM_SRC_DIR)/data_logger.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axi_fifo_sync.vhd
SRC += $(SIM_SRC_DIR)/axi_stim_verf.vhd

# Top level entity
DUT = ip_wrapper_stress

# Test duration
STOP_TIME = 50us

# Test specific generics
GENERIC += -gG_MAX_LENGTH=100
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_SHOW_PACKETS=false
GENERIC += -gG_SHOW_PROTOCOL=false

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

