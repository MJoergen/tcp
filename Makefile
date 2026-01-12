# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the entire project
#

TARGETS += sim
TARGETS += Example_Design

all: $(TARGETS)

.PHONY: sim
sim:
	make -C sim

.PHONY: Example_Design
Example_Design:
	make -C Example_Design

.PHONY: clean
clean:
	make -C sim clean
	make -C Example_Design clean

