# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_pipe_squash.vhd file.

# List of source files
SRC += $(SRC_DIR)/axi_pipe_squash.vhd

# List of test specific simulation files
SRC += tb_axi_pipe_squash.vhd

# Top level entity
DUT = axi_pipe_squash

# Test duration
STOP_TIME = 1us

# Test specific generics
GENERIC += -gG_SHOW_TESTS=true
GENERIC += -gG_SHOW_DATA=false
GENERIC += -gG_FAST=true
GENERIC += -gG_DATA_BYTES=8

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

