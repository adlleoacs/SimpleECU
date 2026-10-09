CXX := arm-none-eabi-g++
OBJCOPY := arm-none-eabi-objcopy
# Where to put build outputs for bootloader
BUILD_DIR := ../build/bootloader

# Debug switch: set DEBUG=1 to build with debug-friendly flags (-Og -g3)
DEBUG ?= 0
ifeq ($(DEBUG),1)
DEBUG_FLAGS := -Og -g3
else
DEBUG_FLAGS := -Os -g3
endif

CPPFLAGS := -ICore/Inc -IDrivers/CMSIS/Include -IDrivers/CMSIS/Device
CXXFLAGS := -std=gnu++20 -mcpu=cortex-m4 -mthumb -mfloat-abi=soft \
	-ffreestanding -fno-exceptions -fno-rtti -fno-use-cxa-atexit \
	-fno-threadsafe-statics -fno-unwind-tables -fno-asynchronous-unwind-tables \
	-fdata-sections -ffunction-sections $(DEBUG_FLAGS) -Wall -Wextra
LDFLAGS := -nostdlib -Wl,--gc-sections -Wl,--build-id=none \
	-Wl,-Map=$(BUILD_DIR)/bootloader.map -TLinker/bootloader.ld

SOURCES := Core/Src/main.cpp \
	Core/Src/bootloader.cpp \
	Core/Src/startup.cpp \
	Core/Src/vector_table.cpp
OBJECTS := $(patsubst %.cpp,$(BUILD_DIR)/%.o,$(SOURCES))

.PHONY: all clean

all: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.elf: $(OBJECTS) Linker/bootloader.ld
	$(CXX) $(CXXFLAGS) $(OBJECTS) $(LDFLAGS) -o $@

$(BUILD_DIR)/bootloader.bin: $(BUILD_DIR)/bootloader.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
