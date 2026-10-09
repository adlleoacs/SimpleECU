# Top-level Makefile for multi-project build (Bootloader and Program)

.PHONY: all clean bootloader program application renode-test renode-debug

# Debug switch
DEBUG ?= 0

BUILD_DIR := build/bootloader
APPLICATION_BUILD_DIR := build/application

all: bootloader program

# Build bootloader
bootloader:
	@echo "Building Bootloader..."
	$(MAKE) -C Bootloader all DEBUG=$(DEBUG)

# Build program/application
program application:
	@echo "Building Program/Application..."
	$(MAKE) -C Program all DEBUG=$(DEBUG)

.PHONY: renode-test
renode-test:
	@echo "Running Renode tests (builds must be present)."
	@bash Renode/run_renode_tests.sh

.PHONY: renode-debug
renode-debug:
	@echo "Starting Renode with GDB server on port 3333 (interactive)."
	@echo "Connect with: arm-none-eabi-gdb $(BUILD_DIR)/bootloader.elf  (then) target remote :3333"
	@renode -e "include @$(PWD)/Renode/nucleog474re.repl; sysbus LoadELF @$(PWD)/$(BUILD_DIR)/bootloader.elf; sysbus LoadELF @$(PWD)/$(APPLICATION_BUILD_DIR)/application.elf; StartGdbServer 3333; start;"

clean:
	$(MAKE) -C Bootloader clean DEBUG=$(DEBUG)
	$(MAKE) -C Program clean DEBUG=$(DEBUG)