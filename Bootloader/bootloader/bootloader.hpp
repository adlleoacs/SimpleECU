#pragma once

namespace Bootloader {

bool boot_entry_requested();
bool application_is_valid();
[[noreturn]] void jump_to_application();
[[noreturn]] void stay_in_bootloader();

}
