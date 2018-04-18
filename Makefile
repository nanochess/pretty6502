# Ultra simple makefile for pretty6502
# by Oscar Toledo G.
# https://github.com/nanochess/pretty6502
#
build:
	@cc pretty6502.c -o pretty6502

clean:
	@rm pretty6502

love:
	@echo "...not war"

