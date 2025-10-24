# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_fifo_squash.vhd file.

# List of source files
SRC += $(SRC_DIR)/axi_fifo_squash.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# List of test specific simulation files
SRC += tb_axi_fifo_squash_stress.vhd

# Top level entity
DUT = axi_fifo_squash_stress

# Test duration
STOP_TIME = 10us

# Test specific generics
GENERIC += -gG_FAST=false
GENERIC += -gG_RANDOM=true

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

