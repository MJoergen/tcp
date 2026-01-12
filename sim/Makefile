# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project

DUTS += tb_design
DUTS += tb_mac_handler

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	make -C $(DUT)

clean:
	for i in $(DUTS); do make -C $$i clean; done

