---
title: "s2idle, S0ix, and S3"
parent: "Power Management"
grand_parent: "English"
nav_order: 1
lang: en
---

# What is Linux s2idle?
s2idle is a sleep mode in Linux's ACPI power management, short for Suspend-to-Idle. It is Linux's implementation of Modern Standby (S0ix): an extension of the ACPI S0 working state, not the traditional S3 (Suspend-to-RAM).
In s2idle:
  - The system looks asleep but stays in the S0 power state.
  - The CPU and memory still get some power, and devices can choose to enter low-power states.
  - It wakes up quickly, like a phone in standby.

## Modern Standby (S0ix) (= Linux s2idle)
- Definition: Modern Standby is a low-power standby mode on Windows platforms. It extends S0 (the working state) so the system can keep its network connection and sync in the background while in standby, like a phone.
- Characteristics:
  - The system looks asleep, but the CPU and memory still get some power.
  - Fast wake-up.
  - Mainly used on Windows 10/11; the hardware must meet the ACPI S0ix requirements.
  - Linux also supports S0ix, but it needs hardware and kernel support (kernel 5.x or later), and "Modern Standby" must be enabled in the BIOS.
  - **On Linux, the mode that corresponds to S0ix is called `s2idle`.**

## S3 (Suspend to RAM)
- Definition: S3 is the traditional ACPI sleep state, commonly called "sleep".
- Characteristics:
    - Linux has supported S3 for a long time.
    - The CPU and devices are fully powered off; only RAM keeps power.
    - Wakes faster than hibernation, but slower than Modern Standby.
    - Widely supported on Linux, Windows, and older hardware.

## Commands
### `$ systemctl suspend`
- The sleep mode `systemctl suspend` uses depends on `/sys/power/mem_sleep`:
    - If the hardware and kernel support S3 (Suspend-to-RAM), it enters S3.
    - If the hardware only supports Modern Standby (S0ix), it enters `s2idle` (Linux's S0ix mode).
- Check it with:
    ```
    cat /sys/power/mem_sleep
    ```
- Possible output:
    - `s2idle [deep]` → deep is S3, s2idle is S0ix.
    - `[s2idle] deep` → the system uses s2idle (Modern Standby) by default.
    - If only `[s2idle]` is shown, with no other option (such as `deep`), the hardware or BIOS does not support S3 (Suspend-to-RAM) and only Linux's s2idle is available.

### `$ rtcwake -m mem`
On Linux, `-m mem` calls Suspend-to-RAM, but the actual mode is decided by `/sys/power/mem_sleep`.
`rtcwake -m mem` does not guarantee S3; it is just the underlying mechanism that `systemctl suspend` also uses.

### `$ cat /sys/power/suspend_stats/total_hw_sleep`
- `total_hw_sleep` is the accumulated time the hardware spent in a low-power state (usually from `/sys/kernel/debug/pmc_core/slp_s0_residency_usec` or a similar hardware counter). It tells you whether the system really reached hardware-level sleep.
- S3 (deep):
    - The system enters ACPI S3; the CPU and devices are powered off, only RAM is kept.
    - The hardware enters deep sleep, so total_hw_sleep almost always increases (the platform reached a low-power state).
- s2idle (Modern Standby):
    - The system is still in S0ix; the CPU has some power and devices may stay active.
    - Whether it increases depends on whether the hardware supports S0ix and correctly enters the low-power state.
    - If the hardware or BIOS is not configured correctly, total_hw_sleep may not increase, or increase only a little.

## Linux Tools and Settings
- [stress_s2idle.sh](https://github.com/chinyakao/linux_tool_script/blob/main/stress/stress_s2idle.sh)
- Intel: https://github.com/intel/S0ixSelftestTool
- AMD: https://github.com/superm1/amd-debug-tools/blob/master/docs/amd-s2idle.md

-  Ubuntu GNOME
    - In Ubuntu's desktop environment (e.g. GNOME), choosing Suspend in the UI uses the same sleep mode as `systemctl suspend`.
    - Suspend in the Ubuntu UI is not fixed to S3 or S0ix. It depends on hardware and kernel support, and by default uses the first available mode (usually s2idle on new hardware).

- Checkbox (Ubuntu test tool)
    - The "Suspend (S3) stress test" in Ubuntu's [Checkbox (test tool)](https://github.com/canonical/checkbox) does not necessarily test only S3 (Suspend-to-RAM). It calls `systemctl suspend`, which picks the mode based on what the platform supports.
    - The test starts out as S3, but at run time it **follows the system setting** and may switch to `s2idle`.
    - If the hardware and kernel do not support S3, it only runs s2idle.
    - If the hardware supports S3 and `/sys/power/mem_sleep` offers `deep`, you must first switch the system to force S3 manually, then run the Checkbox test.
