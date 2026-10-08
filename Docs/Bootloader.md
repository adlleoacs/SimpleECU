BOOTLOADER
bootloader.cpp
      │
      ▼
application_is_valid()
      │
      ├── invalid → recovery()
      │
      └── valid
           │
           ▼
      jump_to_application()
           │
           ├── VTOR
           ├── MSP
           └── reset handler
                         │
                         ▼
                  APPLICATION
                         │
                         ▼
                    isr_reset()
                         │
                         ▼
                       main()
                         │
                         ▼
                    isr_timer()
                         │
                         ▼
                       timer_handler()
                         │
                         ▼
                       timer_callback()