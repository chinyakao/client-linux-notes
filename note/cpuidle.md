# What is `cpuidle`?

`cpuidle` is a **power management subsystem** in the Linux kernel, responsible for transitioning the CPU into various "power-saving states" (called **C-states**) when it is idle.

## What are C-states?

When the CPU is not actively working, it can enter different levels of sleep states to save power:

- **C0**: CPU is executing instructions (active state)
- **C1**: Light idle, quick to wake up
- **C2, C3...Cn**: Deeper idle states that save more power but take longer to wake up

`cpuidle` automatically selects the most appropriate C-state based on system load and hardware support to balance performance and power efficiency.

## Drivers and `cpuidle`

The Linux `cpuidle` framework loads the appropriate idle driver based on the CPU model:

| CPU Vendor | Idle Driver       | Notes |
|------------|-------------------|-------|
| Intel      | `intel_idle`      | Intel-specific, better performance, supports various C-states (C1~C10 depending on CPU model) |
| AMD        | `amd_idle` or `acpi_idle` | Depends on core and platform, supports similar C-state management |
| ARM        | Platform-specific | Uses platform-specific idle drivers (e.g., ARM big.LITTLE architecture, `arm_idle`, `psci_idle`, etc.); supports SoC-specific power states (not always called C-states, but conceptually similar) |
| Others     | Varies by platform | Requires platform support; if an idle driver exists, it can be integrated into the `cpuidle` framework (e.g., RISC-V, PowerPC) |

## How to Check Which Idle Driver is in Use

Run the following command in a Linux terminal:
```
$ cat /sys/devices/system/cpu/cpuidle/current_driver
```
This will show the current idle driver in use, such as:

- `intel_idle`
- `acpi_idle`
- `psci` (for ARM platforms)

## What is Disable `cpuidle`?

Disabling `cpuidle` means preventing the CPU from entering deep idle states, allowing only the most basic idle modes (typically C1 or none at all).

This keeps the CPU in an **active or shallow idle state**, avoiding deeper power-saving modes.

## When to Disable `cpuidle`

1. **Debugging or Testing**: Developers may want to eliminate power-saving effects on performance.
2. **Low-latency Applications**: Real-time systems like audio processing or financial trading require minimal latency.
3. **Hardware Compatibility Issues**: Some hardware may become unstable when entering deep idle states.
4. **Servers or High-Performance Computing (HPC)**: Systems that require consistent high performance may avoid power-saving states.

## Disabling `cpuidle` via Kernel Parameters

**1. `cpuidle.off=1`**

- Completely disables the CPU Idle framework, preventing the system from using any C-state.
- Overrides most other idle settings; if this is enabled, [2] and [3] will have no effect.

**2. `processor.max_cstate=1`**

- Limits the maximum C-state the processor can enter.
- Setting it to 1 disables all deep C-states, allowing only C0 and C1.

**3. `intel_idle.max_cstate=0`**

- Restricts the maximum C-state for the Intel-specific idle driver.
- Setting it to 0 disables the Intel Idle driver entirely.

**4. `idle=poll`**

- Forces the CPU to use a polling loop instead of entering any C-state.
- Greatly increases power consumption but ensures maximum responsiveness.
- Overrides the idle mechanism entirely; the system will not enter any idle state.

**5. `idle=halt`**

- Forces the CPU to use the HLT instruction for idle, avoiding deeper C-states.
- Suitable for light performance tuning.

## Purpose vs. Recommended Parameters

| Purpose                        | Recommended Parameters |
|-------------------------------|------------------------|
| Fully disable CPU idle        | 1, 4                   |
| Disable deep C-states only    | 2, 3                   |
| Light performance tuning      | 5                      |

---

### How to Add Kernel Parameters to Disable `cpuidle`

```bash
$ sudo nano /etc/default/grub
# Add the following line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cpuidle.off=1"
$ sudo update-grub
$ sudo reboot
```

### How to Verify cpuidle is Disabled
**1. Check if kernel parameters are applied**
```bash
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-6.11.0-9002-oem root=UUID=... ro quiet splash intel_idle.max_cstate=0  processor.max_cstate=1
```
**2. Check if `max_cstate` value is `0` or matches your kernel parameter**
```bash
$ sudo cat /sys/module/processor/parameters/max_cstate
```
**3. Check if `cpuidle` driver is inactive (returns nothing or error)**
```bash
$ sudo cat /sys/devices/system/cpu/cpuidle/current_driver
```
