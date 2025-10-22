# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the tcp_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/tcp_protocol.vhd
SRC += $(SRC_DIR)/tcp_wrapper.vhd

# List of test specific simulation files
SRC += tb_tcp_wrapper.vhd

# Top level entity
DUT = tcp_wrapper

# Test duration
STOP_TIME = 2ms

include ../Makefile.inc

