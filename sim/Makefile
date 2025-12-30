# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project

TESTS += tb_axi_stim_verf
TESTS += tb_axi_pipe_flexible
TESTS += tb_ip_wrapper_stress
TESTS += tb_mac_wrapper_stress
TESTS += tb_axis_remove_fixed_header
TESTS += tb_axis_insert_fixed_header
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

