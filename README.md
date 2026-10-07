# STM32G474RE Cooling Fan ECU

A simplified bare-metal implementation of an **electronic control unit (ECU) for an electric cooling fan**, developed for the STM32G474RE microcontroller.

The system is intentionally limited in scope to demonstrate the fundamental elements of an embedded control system without attempting to reproduce a production automotive ECU.

## Application

The ECU represents a controller responsible for regulating the speed of an electric cooling fan according to an analog input representing temperature or thermal load.

The controller:

* Reads an analog sensor signal.
* Reads a digital enable/fault signal.
* Processes a fault through an interrupt.
* Calculates the required fan speed.
* Generates a PWM signal to control the fan.
* Provides digital status output.
* Starts through a dedicated bootloader.

The STM32G474RE is well suited to this application because it combines high-speed ADCs, timers/PWM, comparators, GPIO and interrupt capabilities in a microcontroller designed for real-time control applications.

## System Architecture

The architecture is based on **information hiding and hardware abstraction**. Hardware-specific implementation details are isolated from the application logic so that the control policy does not depend directly on STM32 registers or peripheral configuration.

```text
                         ┌───────────────┐
                         │  Bootloader   │
                         └───────┬───────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │      Application       │
                    │                        │
                    │    Fan Controller      │
                    └───────┬────────┬───────┘
                            │        │
                 ┌──────────┘        └──────────┐
                 ▼                              ▼
        ┌────────────────┐             ┌────────────────┐
        │ Temperature    │             │ Fan Actuator   │
        │ Sensor         │             │                │
        └───────┬────────┘             └───────┬────────┘
                │                              │
                ▼                              ▼
           ADC Interface                  PWM Interface
                │                              │
                └──────────────┬───────────────┘
                               ▼
                    ┌────────────────────┐
                    │ STM32G474RE        │
                    │ Hardware Registers │
                    └────────────────────┘

        Fault Input ──► GPIO ──► Interrupt Handler
                                      │
                                      ▼
                                Fan Controller
```

### Architectural layers

**Application**

Contains the ECU control policy. It determines the required fan speed based on the sensor input and system state.

**Hardware Abstraction**

Provides interfaces for sensors, actuators and system events. The application interacts with these interfaces rather than directly accessing STM32 peripherals.

**Hardware**

Contains the STM32G474RE-specific implementation, including ADC, GPIO, PWM, timers and interrupt configuration.

**Bootloader**

Initializes the system and transfers execution to the application firmware.

## Information Hiding

The architecture follows the principle that modules should hide implementation decisions that are likely to change.

For example, the fan controller should not need to know which timer or channel generates the PWM signal:

```text
FanController
      │
      ▼
 Fan::setSpeed()
      │
      ▼
 PWM implementation
      │
      ▼
 STM32 timer registers
```

Similarly, the temperature source is hidden behind a sensor interface:

```text
FanController
      │
      ▼
Temperature::read()
      │
      ▼
 ADC implementation
      │
      ▼
 STM32 ADC registers
```

This keeps the application logic independent from the STM32G474RE peripheral implementation.

## Interrupt Handling

The fault input is handled asynchronously using an external interrupt.

```text
Fault Signal
     │
     ▼
   GPIO/EXTI
     │
     ▼
Interrupt Vector
     │
     ▼
Interrupt Handler
     │
     ▼
Fan Controller
     │
     ▼
Disable Fan / Enter Safe State
```

The interrupt handler is kept small and is responsible for notifying the application of the event rather than implementing the complete control logic.

## Control Logic

The basic control loop is intentionally simple:

```text
Analog Input
     │
     ▼
   ADC Read
     │
     ▼
Temperature / Load
     │
     ▼
Fan Control Policy
     │
     ▼
PWM Duty Cycle
     │
     ▼
Fan Actuator
```

A fault condition takes priority over normal fan-speed control and can force the actuator into a safe state.

## Main Components

```text
bootloader/
    Firmware startup and application handoff

application/
    ECU control logic

interfaces/
    Hardware-independent interfaces

hardware/
    STM32G474RE peripheral implementations

startup/
    Startup code and interrupt vector table
```

The implementation uses **C++ without HAL or high-level peripheral libraries**. Hardware access is performed through the STM32G474RE registers.

## Design Goals

The project focuses on:

* Bare-metal STM32 development
* Hardware abstraction
* Information hiding
* Interrupt-driven event handling
* Analog signal acquisition
* Digital I/O
* PWM generation
* Bootloader/application separation
* Separation between application policy and hardware implementation

The goal is not to implement a complete automotive ECU, but to provide a **small and coherent embedded control system** whose architecture reflects the characteristics of a real control-oriented microcontroller.
