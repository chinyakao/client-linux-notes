---
title: "thermald"
parent: "Thermal"
grand_parent: "English"
nav_order: 1
lang: en
---

## Overall Thermal Control Architecture

    [ Silicon / Sensors ]
            ↓
    [ EC / PMIC / On-die thermal sensor ]
            ↓
    [ ACPI / Firmware (BIOS / UEFI) ]
        BIOS uses ACPI to "describe" the thermal world
            ↓
    [ Linux Kernel thermal framework ]
        Translates ACPI into sysfs
            ↓
    [ Userspace: thermald / power daemon ]
        Reads sysfs and applies policy
            ↓
    [ Cooling devices: freq / power / fan ]

## HW Level: How Is Temperature Measured?

### 1. Thermal Sensor Types

Common sources:

*   **CPU on-die sensor (DTS)**
    *   Intel: Digital Thermal Sensor
    *   AMD: Tctl / Tdie
*   **SoC sensors**
*   **Board sensor**
    *   via EC, I2C, SMBus
*   **GPU thermal**
*   **VR / PMIC / Battery sensor**

In the end, the BIOS or the kernel exports them as ACPI or hwmon / thermal\_zone.

### 2. What the Hardware Does on Its Own (Without Waiting for the OS)

**Thermal hardware trips (unavoidable)**

*   PROCHOT#
*   THERMTRIP#
*   SoC internal hard limit

⚠️ These are the **last line of defense**

*   The OS has no time to intervene
*   If the temperature is too high, the hardware throttles or shuts down directly

## BIOS / Firmware (ACPI) Layer

### ACPI Thermal Zone
One thermal zone = one logical temperature unit
For example:
* CPU package
* Skin temperature
* VR / motherboard

The BIOS defines thermal policy through ACPI, with concepts like this:
```
Thermal Zone: CPUZ
  - current temperature
  - trip points (explained below)
  - cooling devices
```
### ACPI Trip Point

*   `_TZ`: thermal zone
*   `_TMP`: current temperature
*   `_CRT`: Critical trip (shut down directly, handled by BIOS/HW)
*   `_PSV`: Passive trip (lower frequency, handled by OS throttling)
*   `_HOT`: used for sleep (handled by ACPI?)
*   `_ACx`: Active trip (fan, handled by BIOS or OS)

### ACPI Passive Cooling vs Active Cooling
**Passive cooling (passive throttling, mainly handled by thermald)**
- Lower CPU frequency
- Limit package power
- Do not touch the fan
- Older systems rely on the BIOS; newer systems hand it to the OS (thermald)
- ACPI does not throttle the CPU directly
    - ACPI only says:
    "When the temperature is > 80°C, OS, please start doing something"
    "How" is up to the OS / thermald

**Active cooling (often out of thermald's reach)**
- Fans
- Almost always locked down by the BIOS / EC

### Responsibilities: BIOS vs OS

| Mode                          | Control                      |
| ----------------------------- | ---------------------------- |
| Legacy                        | BIOS controls fans / throttle |
| Modern (Intel recommendation) | OS controls via thermald      |
| Broken BIOS                   | Does everything (debug nightmare) |

**What thermald prefers:**

*   The BIOS provides **sensors + cooling devices**
*   Policy is left to the OS

## Linux Kernel Thermal Framework

The kernel provides the "plumbing" but no policy (policy lives in user space).
The kernel turns ACPI into:
```
thermal zone
trip point
cooling device
```
All of it under:
```
/sys/class/thermal/
```
### Where the Kernel Interface Lives

```bash
/sys/class/thermal/
├── thermal_zone0/
│   ├── temp
│   ├── trip_point_0_temp
│   ├── trip_point_0_type
├── cooling_device0/
│   ├── type
│   ├── cur_state
│   ├── max_state
```

**1. Thermal Zone**
```
ls /sys/class/thermal/thermal_zone*
```
Temperature sources; common ones:
- acpitz (ACPI thermal zone)
- x86_pkg_temp (CPU package sensor)

```
$ cat /sys/class/thermal/thermal_zone0/type
x86_pkg_temp
$ cat /sys/class/thermal/thermal_zone0/temp
57000
```
This means the temperature comes from the CPU package sensor and is currently 57°C (unit: **millidegree Celsius**).

**2. Trip Point**

Temperature thresholds (passive / active / critical)
```
$ cat /sys/class/thermal/thermal_zone0/trip_point_0_type
passive
$ cat /sys/class/thermal/thermal_zone0/trip_point_0_temp
80000
```
This means throttling starts at 80°C.

**3. Cooling Device**
Things the OS can use to lower the temperature:
```
cat /sys/class/thermal/cooling_device*/type
```
Common ones:
- Processor
- intel_powerclamp (CPU power clamp (Intel RAPL))
- Fan (usually not useful)

*   CPU freq?
*   GPU freq?

## What Is thermald and What Does It Do?

### Where thermald Fits

*   Started by Intel (but not Intel-only)
*   **Userspace Thermal Policy Daemon**
*   Based on:
    *   ACPI info
    *   kernel thermal
    *   CPU features (RAPL / P-state)

It decides **when to use which cooling device**.

### What thermald Can Do

*   **CPU frequency limit**
*   **CPU package power limit (RAPL)**
*   CPU core hot-plug (rarely)
*   Fan control (if the BIOS allows it)
*   Coordinating multiple zones

### thermald's Data Sources

```text
/sys/class/thermal/*
/sys/class/hwmon (sysfs hwmon)
ACPI tables
MSR (RAPL / pkg power)
```

## How to "See" the Current Thermal State (Most Important)

### Thermal zones

```bash
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp
```

### All at once

```bash
watch -n1 'paste \
  /sys/class/thermal/thermal_zone*/type \
  /sys/class/thermal/thermal_zone*/temp'
```

### Cooling devices

```bash
cat /sys/class/thermal/cooling_device*/type
cat /sys/class/thermal/cooling_device*/cur_state
```

Common types:

*   `Fan`
*   `Processor`
*   `intel_powerclamp`

### CPU throttling state

```bash
cat /proc/cpuinfo | grep MHz
```
or
```bash
turbostat
```

## thermald Debug Flow

1. Make sure thermald is running
    ```bash
    systemctl status thermald
    ```
2. Foreground debug mode
    ```bash
    thermald --no-daemon --loglevel=debug
    ```

    You will see:
    *   zone register
    *   trip trigger
    *   cooling decision

    What to look for:
    - Which thermal zone was triggered
    - Which cooling device was used
    - How much power / frequency was limited

3. Common debug scenarios
    - Scenario A: high temperature but no throttling
    Check
        * Is there a passive trip?
        * Is the trip point set too high?
        * Does the cooling device exist?
        * Is thermald allowed to operate the cooling device?

        ```bash
        $ cat trip_point*_type
        $ cat cooling_device*/type
        $ cat cooling_device*/max_state
        ```
    - Scenario B: throttled right after boot (stuck at 400MHz as soon as there is load)
    Common causes:
        * BIOS `_PSV` is very low
        * The EC reports a wrong temperature
        ```bash
        dmesg | grep thermal
        ```
    - Scenario C: the fan never spins
        *   The BIOS does not expose fan control
        *   Locked down by the EC
        => thermald **cannot fix it**

**Don't start by changing the thermald config. The debug order should always be:**

1.  Is the HW sensor sane? (confirm the readings make sense)
    ```
    watch -n1 cat /sys/class/thermal/thermal_zone*/temp
    ```
2.  Are the BIOS ACPI tables reasonable?
3.  Did kernel thermal register successfully?
4.  Does thermald have a policy? (check trip points)
    ```
    grep . /sys/class/thermal/thermal_zone*/trip*
    ```
5.  Does the cooling device really affect power / frequency? (confirm it works)
    ```
    watch -n1 cat /sys/class/thermal/cooling_device*/cur_state
    ```
6. Look at what the CPU actually does
    ```
    turbostat
    ```

## Thermal Stress Testing: Verifying Throttling

The goal is not to see how hot it gets, but to verify the chain "temperature crosses a trip → policy → cooling takes effect".

### What to verify

| Item | Question |
| --- | --- |
| Is the trip point actually triggered? | Does anything happen when the temperature goes above `_PSV`? |
| Throttle method | Frequency? Power limit? |
| Throttle strength | Is it excessive? |
| Recovery | Is it released after cooling down? |
| Oscillation | Does it bounce between high and low? |

### Monitoring panels (set these up before applying load)

1. Thermal zones and trip points:
    ```bash
    watch -n1 '
    for z in /sys/class/thermal/thermal_zone*; do
      echo "==== $(cat $z/type) ===="
      echo "temp: $(cat $z/temp)"
      grep . $z/trip_point*_type 2>/dev/null
      grep . $z/trip_point*_temp 2>/dev/null
    done
    '
    ```
2. Cooling device state (what the kernel / thermald actually do):
    ```bash
    watch -n1 '
    for c in /sys/class/thermal/cooling_device*; do
      echo "==== $(cat $c/type) ===="
      echo "cur: $(cat $c/cur_state) / max: $(cat $c/max_state)"
    done
    '
    ```
3. Real CPU behavior (most important; turbostat is more accurate than cpufreq):
    ```bash
    sudo turbostat --interval 1
    ```
    Watch Avg MHz, package power, and throttle flags.

### A controllable load pattern

Don't start with 100% all-core load. All you will see is a temperature spike and hard throttling, and you can't line it up with the trip point.

1. **Warm up (slow rise)**: `stress-ng --cpu 2 --cpu-load 60 --timeout 300s`
    Check whether the temperature slowly approaches `_PSV`, and whether throttling starts early.
2. **Cross trip (deliberately go over)**: `stress-ng --cpu 4 --cpu-load 90 --timeout 300s`
    Note when the temperature crosses `_PSV`, when the cooling device starts acting, and whether the CPU power limit drops.
3. **Sustain (steady state)**: `stress-ng --cpu 4 --cpu-load 90 --timeout 10m`
    What matters is whether it settles at a stable power / frequency, and whether it oscillates.
4. **Cool down (recovery)**: stop the load and confirm the cooling device returns to 0, CPU frequency and power recover, and nothing is stuck throttled.

This flow is scripted, with all data logged; see [Thermal stress test](stress-test.md).

### Is the throttling correct?

- **Normal**: temperature slightly above `_PSV` (about 2–3°C), CPU frequency lowered gradually, package power clearly limited, no violent oscillation.
- **Binary throttle**: jumps back and forth `4GHz → 400MHz → 4GHz → 400MHz`, usually because a trip is set too low or the policy is not smooth.
- **Over-throttle**: the CPU is stuck at a low frequency while the temperature is only around 70°C; check the BIOS `_PSV` first.
- **Skin temperature**: if a laptop has a skin-type thermal zone (for example another `acpitz` zone), its trip may be reached before the CPU zone. Many user experience problems are really skin zone throttling.

## Reading Thermal Settings in the DSDT (Without Learning ACPI Syntax)

There is only one goal: see what the BIOS intends the OS to do about cooling.

1. Dump and disassemble the ACPI tables:
    ```bash
    sudo acpidump > acpi.dump
    acpixtract -a acpi.dump
    iasl -d dsdt.dat
    ```
2. Find the thermal zones: `grep -n "ThermalZone" dsdt.dsl`. You will see something like
    ```asl
    ThermalZone (TZ00) {
        Method (_TMP, 0) { ... }
        Method (_PSV, 0) { ... }
        Method (_CRT, 0) { ... }
    }
    ```
    This block is the thermal contract between the BIOS and the OS.
3. Read the trip point values. ACPI temperatures are in units of 0.1 K:
    ```asl
    Method (_PSV, 0) { Return (0x0C80) }
    ```
    `0x0C80` = 3200 → 320.0 K − 273.15 ≈ 47°C. If `_PSV` is this low, a CPU that is always throttled is **not a Linux bug**.
4. Common BIOS problems:
    - Trip points set too close together, which invites oscillation.
    - The trip value depends on EC state (for example `If (ECST == 1) { Return (LowTemp) }`), so an EC bug turns thermal behavior chaotic.
5. Compare with sysfs: `_PSV` maps to the trip whose `trip_point_*_type` is `passive`, and `_CRT` to `critical`. If the trips the kernel exposes differ from the DSDT, a driver override or quirk is involved.

### Things not to do first

- Modify the DSDT
- Blacklist `acpi_thermal`
- Force a thermald XML config

Observe and prove first, then tune. The value of reading the DSDT is not to change the BIOS, but to know who is really at fault.
