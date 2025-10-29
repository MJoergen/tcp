# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_pipe_squash.vhd file.

# List of source files
SRC += $(SRC_DIR)/axi_pipe_squash.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# List of test specific simulation files
SRC += tb_axi_pipe_squash_stress.vhd

# Top level entity
DUT = axi_pipe_squash_stress

# Test duration
STOP_TIME = 100us

# Test specific generics
GENERIC += -gG_CNT_BITS=12
GENERIC += -gG_FAST=true
GENERIC += -gG_RANDOM=true
GENERIC += -gG_S_DATA_BYTES=10
GENERIC += -gG_M_DATA_BYTES=4

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

