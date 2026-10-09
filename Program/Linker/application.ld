ENTRY(Reset_Handler)

FLASH_BASE = 0x08000000;
FLASH_SIZE = 512K;
APPLICATION_START = 0x08008000;
APPLICATION_END = FLASH_BASE + FLASH_SIZE;
RAM_BASE = 0x20000000;
RAM_SIZE = 128K;

MEMORY
{
    APPLICATION (rx) : ORIGIN = APPLICATION_START, LENGTH = APPLICATION_END - APPLICATION_START
    RAM (xrw) : ORIGIN = RAM_BASE, LENGTH = RAM_SIZE
}

__application_start = ORIGIN(APPLICATION);
__application_end = ORIGIN(APPLICATION) + LENGTH(APPLICATION);
__ram_start = ORIGIN(RAM);
__ram_end = ORIGIN(RAM) + LENGTH(RAM);
__stack_top = __ram_end;
__stack_size = 2K;
__stack_limit = __stack_top - __stack_size;

SECTIONS
{
    .isr_vector ORIGIN(APPLICATION) :
    {
        KEEP(*(.isr_vector))
    } > APPLICATION

    .text :
    {
        . = ALIGN(4);
        *(.text.Reset_Handler)
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > APPLICATION

    .data :
    {
        . = ALIGN(4);
        __data_start = .;
        *(.data*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT> APPLICATION

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    .stack __stack_limit (NOLOAD) :
    {
        . = . + __stack_size;
    } > RAM

    /* Keep assertions minimal for application side; bootloader enforces stricter checks. */
}
