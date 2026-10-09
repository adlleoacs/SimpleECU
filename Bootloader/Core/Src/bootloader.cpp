#include "bootloader.hpp"
#include "stm32g474xx.h"
#include <cstdint>

extern "C" {
extern std::uint32_t __application_start;
extern std::uint32_t __application_end;
extern std::uint32_t __ram_start;
extern std::uint32_t __ram_end;
extern std::uint32_t __application_vector_table_start;
}

namespace {

constexpr std::uint32_t kBootPin = 13U; // PC13 (Nucleo User Button)
constexpr std::uint32_t kBootPinMask = 1U << kBootPin;

std::uint32_t read_vector(std::uint32_t address)
{
	const auto* vector = reinterpret_cast<const volatile std::uint32_t*>(address);
	return *vector;
}

}

namespace Bootloader {

bool boot_entry_requested()
{
	RCC->AHB2ENR |= RCC_AHB2ENR_GPIOCEN;
	(void)RCC->AHB2ENR;

	GPIOC->MODER &= ~(3U << (kBootPin * 2U));
	GPIOC->PUPDR = (GPIOC->PUPDR & ~(3U << (kBootPin * 2U))) |
				   (1U << (kBootPin * 2U));

	const bool requested = (GPIOC->IDR & kBootPinMask) == 0U;
	RCC->AHB2ENR &= ~RCC_AHB2ENR_GPIOCEN;
	return requested;
}

bool application_is_valid()
{
	const std::uint32_t application_start =
		reinterpret_cast<std::uintptr_t>(&__application_start);
	const std::uint32_t application_end =
		reinterpret_cast<std::uintptr_t>(&__application_end);
	const std::uint32_t ram_start = reinterpret_cast<std::uintptr_t>(&__ram_start);
	const std::uint32_t ram_end = reinterpret_cast<std::uintptr_t>(&__ram_end);

	const std::uint32_t initial_stack_pointer = read_vector(application_start);
	const std::uint32_t reset_vector = read_vector(application_start + sizeof(std::uint32_t));
	const std::uint32_t reset_address = reset_vector & ~1U;

	const bool stack_is_valid =
		(initial_stack_pointer & 7U) == 0U &&
		initial_stack_pointer >= ram_start &&
		initial_stack_pointer <= ram_end;
	const bool reset_is_valid =
		(reset_vector & 1U) != 0U &&
		reset_address >= application_start &&
		reset_address < application_end;

	return stack_is_valid && reset_is_valid;
}

[[noreturn]] void jump_to_application()
{
	if (!application_is_valid()) {
		stay_in_bootloader();
	}

	const std::uint32_t application_start =
		reinterpret_cast<std::uintptr_t>(&__application_start);
	const std::uint32_t initial_stack_pointer = read_vector(application_start);
	const std::uint32_t reset_vector = read_vector(application_start + sizeof(std::uint32_t));

	__disable_irq();
	SysTick->CTRL = 0U;

	const std::uint32_t interrupt_register_count = (SCnSCB->ICTR & 0xFU) + 1U;
	for (std::uint32_t index = 0U; index < interrupt_register_count; ++index) {
		NVIC->ICER[index] = 0xFFFFFFFFU;
		NVIC->ICPR[index] = 0xFFFFFFFFU;
	}

	RCC->AHB2ENR &= ~RCC_AHB2ENR_GPIOCEN;
	SCB->VTOR = reinterpret_cast<std::uintptr_t>(&__application_vector_table_start);
	__DSB();
	__ISB();

	const auto reset_handler = reinterpret_cast<void (*)(void)>(reset_vector);
	__asm volatile(
		"msr msp, %0\n"
		"bx %1\n"
		:
		: "r"(initial_stack_pointer), "r"(reset_handler)
		: "memory");

	__builtin_unreachable();
}

[[noreturn]] void stay_in_bootloader()
{
	for (;;) {
		__asm volatile("wfi");
	}
}

}
