# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project

all:
	make -C tb_axi_fifo_squash
	make -C tb_axi_fifo_squash_stress
	make -C tb_axi_fifo_wide
	make -C tb_tcp_wrapper

clean:
	make -C tb_axi_fifo_squash clean
	make -C tb_axi_fifo_squash_stress clean
	make -C tb_axi_fifo_wide clean
	make -C tb_tcp_wrapper clean

