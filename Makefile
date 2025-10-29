# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project
#


DIRS += formal
DIRS += sim

.PHONY: run
run: $(patsubst %,%/PASS,$(DIRS))

.PHONY: %/PASS
%/PASS: DIR=$(patsubst %/PASS,%,$@)
%/PASS:
	make -C $(DIR)

clean: $(patsubst %,%/CLEAN,$(DIRS))

.PHONY: %/CLEAN
%/CLEAN: DIR=$(patsubst %/CLEAN,%,$@)
%/CLEAN:
	make -C $(DIR) clean

