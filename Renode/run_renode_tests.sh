#!/usr/bin/env bash
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BOOT_ELF="$ROOT_DIR/build/bootloader/bootloader.elf"
APP_ELF="$ROOT_DIR/build/application/application.elf"
RENODE_SCRIPT="$ROOT_DIR/Renode/nucleog474re.repl"

APP_RESET_HEX=$(arm-none-eabi-nm -n "$APP_ELF" | awk '/ Reset_Handler/{print $1; exit}')

echo "---- Running scenario: boot_to_app ----"
cat << RE_EOF > /tmp/test_boot_to_app.resc
using sysbus
mach create "nucleo"
machine LoadPlatformDescription @$RENODE_SCRIPT
sysbus LoadELF @$APP_ELF
sysbus LoadELF @$BOOT_ELF
sysbus.gpioc.userbutton Release
cpu0 AddHook 0x${APP_RESET_HEX#0x} "print 'BOOT_TO_APP_SUCCESS'; quit"
start
sleep 2
print 'BOOT_TO_APP_TIMEOUT'
quit
RE_EOF

out=$(renode --console -e "include @/tmp/test_boot_to_app.resc" 2>&1 || true)
if echo "$out" | grep -q 'BOOT_TO_APP_SUCCESS'; then
    echo "BOOT_TO_APP: PASS (Jumped to Application Reset_Handler)"
else
    echo "BOOT_TO_APP: FAIL (Output below)"
    echo "$out"
fi

echo "---- Running scenario: bootloader_hold ----"
cat << RE_EOF > /tmp/test_bootloader_hold.resc
using sysbus
mach create "nucleo"
machine LoadPlatformDescription @$RENODE_SCRIPT
sysbus LoadELF @$APP_ELF
sysbus LoadELF @$BOOT_ELF
sysbus.gpioc.userbutton Press
cpu0 AddHook 0x${APP_RESET_HEX#0x} "print 'BOOT_TO_APP_SUCCESS'; quit"
start
sleep 2
print 'BOOTLOADER_HOLD_SUCCESS'
quit
RE_EOF

out=$(renode --console -e "include @/tmp/test_bootloader_hold.resc" 2>&1 || true)
if echo "$out" | grep -q 'BOOT_TO_APP_SUCCESS'; then
    echo "BOOTLOADER_HOLD: FAIL (Jumped to Application!)"
elif echo "$out" | grep -q 'BOOTLOADER_HOLD_SUCCESS'; then
    echo "BOOTLOADER_HOLD: PASS (Stayed in Bootloader)"
else
    echo "BOOTLOADER_HOLD: FAIL (Unknown output below)"
    echo "$out"
fi
