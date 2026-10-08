#include "bootloader.hpp"

int main()
{
	if (Bootloader::boot_entry_requested()) {
		Bootloader::stay_in_bootloader();
	}

	if (Bootloader::application_is_valid()) {
		Bootloader::jump_to_application();
	}

	Bootloader::stay_in_bootloader();
}
