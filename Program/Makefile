CXX := arm-none-eabi-g++
OBJCOPY := arm-none-eabi-objcopy
# Where to put build outputs for application
BUILD_DIR := ../build/application
APPLICATION_LINKER := Linker/application.ld

# Debug switch: set DEBUG=1 to build with debug-friendly flags (-Og -g3)
DEBUG ?= 0
ifeq ($(DEBUG),1)
DEBUG_FLAGS := -Og -g3
else
DEBUG_FLAGS := -Os -g3
endif

CPPFLAGS := -IDrivers/CMSIS/Include \
	-IDrivers/CMSIS/Device/ST/STM32G4xx/Include \
	-ICore/Inc -IApp/Inc
CXXFLAGS := -std=gnu++20 -mcpu=cortex-m4 -mthumb -mfloat-abi=soft \
	-ffreestanding -fno-exceptions -fno-rtti -fno-use-cxa-atexit \
	-fno-threadsafe-statics -fno-unwind-tables -fno-asynchronous-unwind-tables \
	-fdata-sections -ffunction-sections $(DEBUG_FLAGS) -Wall -Wextra

.PHONY: all clean

all: $(BUILD_DIR)/application.bin

APPLICATION_SOURCES := App/Src/main.cpp \
    App/Src/vector_table.cpp \
    App/Src/startup.cpp \
    App/Src/fan_controller.cpp \
    Core/Src/adc.cpp \
    Core/Src/gpio.cpp \
    Core/Src/interrupt.cpp \
    Core/Src/pwm.cpp
APPLICATION_OBJECTS := $(patsubst %.cc,$(BUILD_DIR)/%.o,$(patsubst %.cpp,$(BUILD_DIR)/%.o,$(APPLICATION_SOURCES)))

$(BUILD_DIR)/application.elf: $(APPLICATION_OBJECTS) $(APPLICATION_LINKER)
	$(CXX) $(CXXFLAGS) $(APPLICATION_OBJECTS) -nostdlib -Wl,--gc-sections -Wl,--build-id=none -Wl,-Map=$(BUILD_DIR)/application.map -T$(APPLICATION_LINKER) -o $@

$(BUILD_DIR)/application.bin: $(BUILD_DIR)/application.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
