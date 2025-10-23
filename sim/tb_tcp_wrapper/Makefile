# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the tcp_wrapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/tcp_protocol.vhd
SRC += $(SRC_DIR)/tcp_wrapper.vhd

# List of test specific simulation files
SRC += tb_tcp_wrapper.vhd
SRC += data_logger.vhd

# Top level entity
DUT = tcp_wrapper

# Test duration
STOP_TIME = 2us

# Test specific generics
#GENERIC += -gG_SHOW_TESTS=true
#GENERIC += -gG_SHOW_PACKETS=true
#GENERIC += -gG_SHOW_PROTOCOL=true

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

