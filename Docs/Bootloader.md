# STM32G474RE Bare-Metal Bootloader

This bootloader is a freestanding C++ image for the STM32G474RE (Cortex-M4). It does not use HAL, LL, an RTOS, or CubeMX startup code. The checked-in CMSIS device header is used for register and address definitions only.

## Files and responsibilities

| File | Why it exists and how it connects | Hardware-specific or CPU/linker requirement |
| --- | --- | --- |
| `Core/startup/vector_table.cpp` | Supplies the initial MSP, `Reset_Handler`, core exception defaults, and all 102 STM32G474 external IRQ entries. Unused entries point to `Default_Handler`. | Cortex-M vector format and the G474 IRQ count are hardware/CPU-specific. The section name and 512-byte alignment cooperate with the linker script. |
| `Core/startup/startup.cpp` | Implements reset-time `.data` copying, `.bss` clearing, preinit/init array calls, then enters `main()`. | The vector table loads the initial stack before this code runs. Data/array boundaries are exported by the linker script. |
| `Core/main.cpp` | Applies boot policy: stay in recovery mode when the boot pin is asserted, otherwise validate and launch the application; invalid images stay in the bootloader. | Policy is hardware-independent; it calls the separated GPIO, validation, and jump functions. |
| `Core/bootloader/bootloader.hpp` | Declares the small public bootloader interface used by `main()`. | C++ interface only. |
| `Core/bootloader/bootloader.cpp` | Samples the boot pin, validates the application vectors against linker-provided ranges, then disables bootloader interrupts/peripheral use and transfers control. | GPIOA/PA0 and Cortex-M NVIC, SysTick, VTOR, MSP registers are hardware-specific. Memory ranges and vector location come from linker symbols. |
| `linker/bootloader.ld` | Places vectors/code in the reserved boot Flash, data in SRAM, reserves stack space, emits startup symbols, and defines application boundaries. | The Flash/SRAM sizes and addresses match the STM32G474RE. `APPLICATION_START` is the project configuration value. |
| `Makefile` | Builds only the bootloader sources with the ARM cross compiler and freestanding C++ flags, then emits ELF and BIN images. | The target flags select Cortex-M4 Thumb. No runtime, HAL, or generated startup is linked. |

## Memory layout

`linker/bootloader.ld` is the bootloader linker script. By default it reserves 32 KiB for the bootloader and starts the application at `0x08008000`; the total Flash is 512 KiB and SRAM is 128 KiB. To move the application, change the single `APPLICATION_START` assignment. The script derives `__bootloader_start`, `__bootloader_end`, `__application_start`, `__application_end`, `__vector_table_start`, `__application_vector_table_start`, `__ram_start`, and `__ram_end`; the C++ sources do not repeat these memory addresses.

The bootloader is linked at the start of `BOOTLOADER`. The application region is reserved for bounds checking and is not populated by the bootloader link. The script also exports `.data`, `.bss`, constructor-array, and stack symbols. A linker assertion checks the vector-table size, application alignment, region boundary, and RAM/stack collision.

The application must use its own linker script with its Flash origin set to the same `APPLICATION_START` and its Flash length set to `APPLICATION_END - APPLICATION_START` (480 KiB with the default layout). It must place its own vector table at the beginning of that region, keep its initial stack pointer in the valid SRAM range, and link its reset handler into its application Flash region. Program the application image at that origin; a binary linked for `0x08000000` cannot be made relocatable by the bootloader.

The provided boot-entry example uses PA0 as an active-low input with an internal pull-up. Hold the configured pin low during reset/startup to remain in the bootloader. Change `kBootPin`, GPIO port setup, and polarity in `bootloader.cpp` to match the board wiring. This is a software GPIO decision; it is independent of the STM32 BOOT0/nBOOT option-byte configuration.

## Application checks and handoff

The minimum validation checks are deliberately structural, not cryptographic:

- The application's initial MSP is 8-byte aligned and lies within the linker-defined SRAM range. The top-of-SRAM value is accepted as a valid descending-stack initial pointer.
- The reset vector has the Thumb bit set, and its address with that bit removed lies inside the application Flash range.

These checks reject common erased/corrupt vectors but do not establish image authenticity or integrity. Add a CRC/signature check before launch if the update threat model requires one.

When launching, the bootloader disables interrupts, stops SysTick, disables and clears pending NVIC interrupts, disables the GPIO clock it enabled, updates `SCB->VTOR`, executes data/instruction barriers, writes the application's MSP, and branches to its reset vector. The application reset handler then performs its own C++ runtime initialization. The bootloader does not alter BOOT0 or option bytes.

## Build

With `arm-none-eabi-g++` and `arm-none-eabi-objcopy` on `PATH`, run `make`. Outputs are written under `build/bootloader/`. The build uses `-ffreestanding`, disables exceptions and RTTI, avoids the C++ runtime startup, and uses the custom linker script. On hardware, connect the application image at the configured origin and wire the boot pin with the specified polarity.

## Reset sequence

1. Reset loads the initial MSP from vector entry 0 and the bootloader `Reset_Handler` address from vector entry 1.
2. `Reset_Handler` copies `.data` from Flash to SRAM and zeros `.bss`.
3. It calls any preinit and C++ `.init_array` constructors, then enters `main()`.
4. `main()` checks the dedicated GPIO boot-entry pin. If asserted, execution remains in the bootloader. Otherwise it checks the application MSP and reset vector using linker-defined bounds.
5. An invalid application remains in the bootloader; a valid application enters the handoff.
6. The handoff disables interrupts and SysTick, clears NVIC enable/pending state, updates VTOR to the application's vector table, and executes barriers.
7. It loads the application MSP and branches to the application's reset handler.

In short: **Reset → vector table → Reset_Handler → runtime initialization → boot decision → application validation → VTOR update → MSP update → application Reset_Handler.**