#include <cstdint>

extern "C" {
extern std::uint32_t __stack_top;
[[noreturn]] void Reset_Handler();
[[noreturn]] void Default_Handler();
}

extern "C" [[noreturn]] void Default_Handler()
{
	for (;;) {
		__asm volatile("wfi");
	}
}

#define DEFAULT_VECTOR reinterpret_cast<std::uintptr_t>(&Default_Handler)
#define DEFAULT_2 DEFAULT_VECTOR, DEFAULT_VECTOR
#define DEFAULT_4 DEFAULT_2, DEFAULT_2
#define DEFAULT_8 DEFAULT_4, DEFAULT_4
#define DEFAULT_16 DEFAULT_8, DEFAULT_8
#define DEFAULT_32 DEFAULT_16, DEFAULT_16
#define DEFAULT_64 DEFAULT_32, DEFAULT_32
#define DEFAULT_EXTERNAL_VECTORS DEFAULT_64, DEFAULT_32, DEFAULT_4, DEFAULT_2

extern "C" __attribute__((used, section(".isr_vector"), aligned(512)))
const std::uintptr_t vector_table[118] = {
	reinterpret_cast<std::uintptr_t>(&__stack_top),
	reinterpret_cast<std::uintptr_t>(&Reset_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	0U,
	0U,
	0U,
	0U,
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	0U,
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	reinterpret_cast<std::uintptr_t>(&Default_Handler),
	DEFAULT_EXTERNAL_VECTORS
};

#undef DEFAULT_EXTERNAL_VECTORS
#undef DEFAULT_VECTOR
#undef DEFAULT_64
#undef DEFAULT_32
#undef DEFAULT_16
#undef DEFAULT_8
#undef DEFAULT_4
#undef DEFAULT_2
