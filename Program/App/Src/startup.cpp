#include <cstdint>

extern "C" {
extern std::uint32_t __data_load_start;
extern std::uint32_t __data_start;
extern std::uint32_t __data_end;
extern std::uint32_t __bss_start;
extern std::uint32_t __bss_end;

using InitFunction = void (*)();
extern InitFunction __preinit_array_start[];
extern InitFunction __preinit_array_end[];
extern InitFunction __init_array_start[];
extern InitFunction __init_array_end[];

int main();
}

namespace {

void initialize_memory()
{
	auto* source = &__data_load_start;
	for (auto* destination = &__data_start; destination < &__data_end; ++destination) {
		*destination = *source++;
	}

	for (auto* destination = &__bss_start; destination < &__bss_end; ++destination) {
		*destination = 0U;
	}
}

void run_constructors(InitFunction* begin, InitFunction* end)
{
	for (auto* constructor = begin; constructor < end; ++constructor) {
		(*constructor)();
	}
}

}

extern "C" [[noreturn]] void Reset_Handler()
{
	initialize_memory();
	run_constructors(__preinit_array_start, __preinit_array_end);
	run_constructors(__init_array_start, __init_array_end);
	(void)main();

	for (;;) {
		__asm volatile("wfi");
	}
}
