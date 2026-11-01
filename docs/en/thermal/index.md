---
title: "Thermal"
parent: "English"
nav_order: 3
has_children: true
lang: en
---

# Linux Thermal Framework
```
──────────────────────────────────────────────
[ Layer 4: User Space ]
    • thermald (basic cooling daemon)
    • dptfxtract (reads ACPI tables, this tool is archived)
    • (Windows/ChromeOS have ESIF + Policy Manager; Ubuntu does not)
──────────────────────────────────────────────
[ Layer 3: OS Kernel Level ]
    • Linux Thermal Framework
    • INT340x DPTF drivers (read the ACPI DPTF tables)
    • intel_rapl / powercap (RAPL subsystem)
    • cpufreq / intel_pstate
──────────────────────────────────────────────
[ Layer 2: Platform Power Control (MMIO level) (firmware runtime)]
    • Driven by the Intel SoC / PCH / EC
    • MMIO RAPL Power Limits (can override OS settings)
    • DPTF / DTT runtime control
──────────────────────────────────────────────
[ Layer 1: Firmware / ACPI tables (OEM/BIOS) (firmware static)]
    • DPTF ACPI tables:
        - PSVT (Passive Policy Table)
        - PPCC (Power/Performance Capabilities)
        - ART / TRT (thermal relationships)
        - Virtual sensors
    • OEM tuning: PL1/PL2 limits, skin temp, chassis temp
    • RAPL defaults (via MSR/MMIO)
    → policy tables live here, e.g. example-psvt
──────────────────────────────────────────────
[ Layer 0: Hardware / Sensors ]
    • CPU thermal sensor / DTS
    • GPU / PCH / Memory sensors
    • Power rails / RAPL energy counters
──────────────────────────────────────────────
```

## Intel DPTF vs. Intel DTT vs. thermald
1. **Linux Thermal Framework: the kernel's native thermal management architecture**
    Thermal zones, cooling devices, trip points, and so on. Each SoC/CPU vendor plugs into this framework with a driver.
    Example: TI shows how to use the thermal framework on Linux for DFS/passive cooling.
    Sources: TI application note, overviews of the Linux thermal ecosystem.
    Reference: TI App Note (Linux Thermal Framework section) [\[ti.com\]](https://www.ti.com/lit/an/sdaa069/sdaa069.pdf?ts=1769136051597)

2. **Intel DPTF (Dynamic Platform and Thermal Framework)**
    **A platform-level thermal and power management framework (mainly used on Windows, partly on Linux)**
    - Background: DPTF came first, to handle cooling for Ultrabooks and low-power platforms.
    - OS interface: mainly Windows; some features are available to Linux through ACPI.
    - Core ideas:
        - ACPI tables (DPTF tables) describe the platform's temperature nodes (sensors) and cooling devices.
        - It adjusts CPU / GPU / platform power, fans, and skin temperature.
        - Firmware defines it and the OS cooperates.
        - On Linux, drivers such as **INT340x** expose these in sysfs so user space (e.g. thermald) can read them.
    - Level: firmware + OS (ACPI / Microsoft drivers)
    → DPTF is a complete framework: specification + BIOS/firmware + driver.
    **References**: Linux kernel DPTF interface documentation; overview of DPTF integration on Linux/ChromeOS. [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

3. **Intel DTT (Dynamic Tuning Technology, Adaptix family)**
    **A new-generation telemetry + thermal framework, the "next generation" of DPTF**
    - Goals:
        - Replace the traditional ACPI mechanism of DPTF.
        - Bring in more flexible telemetry (not only temperature, but many platform metrics).
        - Intel's **runtime tuner** technology (mostly on Windows/OEM side).
        - Dynamically changes turbo/PL limits, and even mitigates RF interference.
        - Tightly integrated with Windows 11 and new hardware; Linux has no complete official DTT framework.
    - Architectural differences:
        - Moves from ACPI-based to the Intel Telemetry Hub.
        - Focuses on data transport, AI-based policy tuning, and OEM customization.
    - OS support: mainly Windows 10/11; Linux support is less complete than Windows.
    → DTT can be seen as the successor of DPTF, with more emphasis on telemetry and data-driven policy tuning.
    **References**: Intel and vendor guides and technical explanations. [\[novintrades.com\]](https://www.novintrades.com/articles/5372?title=intel-dynamic-tuning-technology-complete-guide-practical-how-to), [\[mundobytes.com\]](https://mundobytes.com/en/What-is-Intel-DTT-Dynamic-Tuning-and-how-does-it-relate-to-APO/)

4. **thermald (Intel Thermal Daemon)**
    **Intel's official thermal daemon for Linux**
    - Platform: Linux only
    - Goals:
        - Uses the Linux thermal subsystem (/sys/class/thermal).
        - An open source user space daemon that reads sysfs/ACPI/DPTF tables and does basic passive/active cooling (lowering frequency, spinning up fans, powerclamp).
        - Dynamically adjusts CPU frequency, power capping, and fans.
        - Helps Linux cool Intel CPU platforms more effectively.
        - It is **not** a complete DPTF policy engine.
    - How it works:
        - Reads the passive and active devices of the Linux thermal layer.
        - Decides cooling actions based on temperature.
        - Can control the CPU through MSR, RAPL, and similar interfaces.
    → thermald is a Linux user space daemon. It depends on neither DPTF nor DTT; it is a standalone Linux solution.
    - What **thermald can do** on Ubuntu
        - Monitor thermal zones (/sys/class/thermal).
        - Read ACPI DPTF tables (e.g. PSVT: example-psvt).
        - Do passive cooling: lower frequency (cpufreq/intel\_pstate), fans, powerclamp.
        - But it **cannot run the complete DPTF policies (Adaptive Performance, Power Boss…)**.
    - What **thermald cannot do (or only partly)** on Ubuntu
        - The full **ESIF/Policy Manager** feature set (Adaptive Performance, Power Boss, Virtual Sensor, Cooling Mode, and so on).
        - Platform-level coordination of **PL1/PL2/Tau** (especially across MMIO/EC/charger/GPU/battery).
        → thermald may try to lower PL1 to 20 W according to example-psvt,
        → but **the platform MMIO layer may set PL1 back to 40 W** (see the next section).

    **References**: thermald project README; kernel documentation for the DPTF sysfs interface. [\[github.com\]](https://github.com/intel/thermal_daemon), [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html)

5. Table

    | Item | Intel DPTF | Intel DTT | thermald |
    | ---- | ---------- | --------- | -------- |
    | Main platform | Windows (limited Linux support) | Windows 10/11 | Linux |
    | Nature | ACPI-based thermal framework | New-generation telemetry + thermal framework | Linux user space daemon |
    | Lineage | Traditional solution | Successor and enhancement of DPTF | Independent, no strong dependency on DPTF/DTT |
    | Control path | ACPI + driver | Telemetry Hub + driver | Linux thermal subsystem |
    | What it controls | CPU/GPU/fan/skin temperature | Finer grained + AI policy | CPU/fans through Linux thermal zones |

## Others
1. **PL1 / PL2 / Tau**
    Power limits of Intel RAPL (Running Average Power Limit).
    Both firmware and OS influence them. This is a general power management concept, related to the MSR/MMIO implementations below.
    - PL1 = long-term power (roughly TDP)
    - PL2 = short-term burst power
    - Tau = how long PL2 can last
2. **MSR vs. MMIO (two implementation/control levels)**
    - **MSR (Model Specific Register)**
        - Registers inside the CPU; the OS can access them with `rdmsr/wrmsr`.
        - Traditional RAPL (PL1/PL2) often uses MSRs.
    - **MMIO (Memory-Mapped I/O)**
        - Driven by BIOS / EC / PCH / DPTF / DTT through memory-mapped registers.
        - Comes from the ACPI PPCC limits.
        - **New-generation Intel platforms mostly use MMIO, which has higher priority than MSR and can override the MSR settings.**

## How Ubuntu and ChromeOS differ on DPTF/DTT

-   **ChromeOS**
    Google and Intel did a complete **platform integration**: ESIF (DPTF core), Policy Manager, and participants are all part of the system. The OEM and Google also make sure the BIOS/ACPI tables are complete, driver timing is correct, and policies actually take effect.
    **Reference**: documentation on DPTF integration in ChromeOS/Linux. [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

-   **Ubuntu (general Linux distributions)**
    The kernel has INT340x and the thermal framework, and user space has thermald, so it **can read the DPTF ACPI tables**. But there is **no ESIF or complete policy engine**, so it mostly does basic cooling. OEMs also rarely tune DPTF policies for Ubuntu, so the real behavior differs from ChromeOS/Windows.
    **References**: Linux kernel DPTF documentation, thermald project. [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[github.com\]](https://github.com/intel/thermal_daemon)


> **Key idea**: Ubuntu can "see" the DPTF policy names and tables in firmware (such as `example-psvt`), but it mostly **only reads and prints them**. It does not fully apply them with ESIF/Policy Manager the way ChromeOS/Windows do.

## Summary

*   **Linux thermal** is the kernel's native thermal management. **DPTF** is Intel's platform-level policy (through ACPI/firmware); Linux has drivers that can read it but **lacks ESIF**. **DTT** is Adaptix runtime tuning (mainly Windows/OEM). [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)
*   On Ubuntu, **thermald** only does "basic cooling"; it is **not** a complete DPTF policy engine. [\[github.com\]](https://github.com/intel/thermal_daemon)
*   **PL1/PL2/Tau** decide long-term power, short-term power, and bursts. **MSR** is a CPU-level setting, **MMIO** is a platform-level setting, and **MMIO often overrides MSR**.
*   The **`example-psvt`** you see is a **DPTF Passive Policy (PSVT)** entry in BIOS/ACPI. Ubuntu can "read" it but may not fully "apply" it; whether it takes effect is decided by **firmware/MMIO**. [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html)
*   On **ChromeOS**, thanks to the complete Google + Intel integration (ESIF/participants/policies/validation), DPTF is fully applied. **Ubuntu** usually only reads the tables and does basic cooling, without the OEM's complete policies or ESIF. [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

## Measurement tools

[Thermal stress test](stress-test.md): staged load while recording thermal zones, cooling devices, cpufreq, and turbostat, with a script to compare two runs.
