# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project

TESTS += tb_stim_verf
TESTS += tb_axi_fifo_squash
TESTS += tb_axi_fifo_squash_stress
#TESTS += tb_axi_fifo_wide
#TESTS += tb_axi_fifo_wide_stress
#TESTS += tb_ip_wrapper_stress
#TESTS += tb_tcp_wrapper
#TESTS += tb_tcp_wrapper_stress

.PHONY: run
run: $(patsubst %,%/PASS,$(TESTS))

%/PASS: TEST=$(patsubst %/PASS,%,$@)
%/PASS:
	make -C $(TEST)

clean: $(patsubst %,%/CLEAN,$(TESTS))

.PHONY: %/CLEAN
%/CLEAN: TEST=$(patsubst %/CLEAN,%,$@)
%/CLEAN:
	make -C $(TEST) clean

