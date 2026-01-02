# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project

TESTS += tb_design
TESTS += tb_mac_handler

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

