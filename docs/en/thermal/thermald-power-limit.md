---
title: "PL1/PL2 and RAPL"
parent: "Thermal"
grand_parent: "English"
nav_order: 2
lang: en
---

# Linux Thermald: CPU package power limit (RAPL)
## How PL1/PL2 Are Decided (MSR vs. MMIO and Common Ubuntu Behavior)

> On modern Intel platforms, **the effective PL1/PL2 is mostly decided by the platform layer (MMIO/firmware/DPTF/DTT)**. Values the OS sets through MSR may be overwritten.

**Text diagram (top to bottom, priority high → low):**
```
[ Firmware / ACPI ]
    - ACPI DPTF Tables (PSVT/ART/TRT/PPCC/...)
        → define PL1 Max and derating policies (including optimized‑28h)
    - OEM tuning
         ↓ (written into platform-level parameters)
────────────────────────────────────
[Platform Control (MMIO)]
   - SoC/PCH/EC actually control the effective PL1/PL2
   - Can overwrite MSR settings
         ↓ (this is what really decides the final PL1/PL2)
────────────────────────────────────
[OS Kernel (powercap / intel_rapl / cpufreq)]
    - Linux kernel thermal framework (INT340x, i915, cpufreq...)
    - If thermald changes MSR PL1 (MSR sets RAPL PL1/PL2) → may be overwritten by MMIO
    - powercap/rapl reports the final power
                ↓
────────────────────────────────────
[ User Space ]
   - thermald: reads ACPI → tries to adjust cooling / freq
   - dptfxtract: decodes ACPI tables (optimized‑28h is read here)
```

**Common Ubuntu scenario:**

*   thermald (or you, by hand) changes the **MSR** PL1 to 20W
*   **MMIO/firmware still keeps PPCC/MAX=40W** and writes it back periodically → **the final value is still 40W**
*   Result: you see the MSR briefly at 20W, but the power/performance curve still stays close to 40W
    **References**: the DPTF/ACPI data path on Linux and thermald's role. [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)


## How to Read the `optimized‑28h` Rule in the Log
- **It is a DPTF policy definition in the BIOS/ACPI firmware (usually a Passive Policy / PSVT entry).**
- Linux (including Ubuntu) exposes ACPI binary tables such as **data\_vault** through the **INT340x** driver. thermald or tools (such as dptfxtract) can **dump/decode** the entries you see (such as `optimized‑28h`), **but that does not mean Ubuntu has a complete DPTF executor**.
- This is a **Passive Policy (PSVT)** setting: it sets **PL1** in steps according to **CPU temperature**.
    ```
    $ sudo systemctl stop thermald
    $ sudo thermald --no-daemon --loglevel=debug --adaptive > thermald_log.log
    ```

    Set matched:1 -> This means the condition_set 1 in APCT is matched, as follows:
    ```
    [1769055982][INFO]..apct dump begin..
    [1769055982][INFO]condition_set 1
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem0 comparison:ADAPTIVE_EQUAL argument:0 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem1 comparison:ADAPTIVE_EQUAL argument:0 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem2 comparison:ADAPTIVE_EQUAL argument:1 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0
    [1769055982][INFO] target:1 device:\_SB_.PC00.LPCB.ECDV.TSKN condition:Temperature comparison:ADAPTIVE_LESSER_OR_EQUAL argument:3272 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0
    ```
    target:1 -> This means the policy with target_id:1 will be loaded.
    Here, PL1MAX and PL2PowerLimit are both set to 40W, and the PSVT table "optimized-28h" will be applied.

    ```
    [1769055982][INFO]..apat dump begin..
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.PC00.TCPU domain:9 code:PL1MAX argument:40000
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.PC00.TCPU domain:9 code:PL2PowerLimit argument:40000
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.IETM domain:14 code:PSVT argument:optimized-28h
    ```
    Below is the definition of "optimized-28h". It defines which PL1 is set at which sensor temperature.
    So, under 50℃, PL1 is MAX, that is, 40W.

    ```
    [1769055982][INFO]..psvt dump begin..
    [1769055982][INFO]Name :optimized-28h
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:50 domain:9 control_knob:65536 psv.limit:MAX
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:55 domain:9 control_knob:65536 psv.limit:20000
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:65 domain:9 control_knob:65536 psv.limit:20000
    ```

## In Practice: Finding Out "Who Controls PL1/PL2" on Ubuntu


> **Goal**: tell the **MSR value** apart from the **effective value (usually controlled by MMIO/firmware)**.

**Suggested steps (overview):**

1.  **Read the ACPI/DPTF tables**
    Compare the dump/decode output of thermald/dptfxtract (look for PSVT, PPCC, ART/TRT).
    ```
    $ sudo systemctl stop thermald
    $ sudo thermald --no-daemon --loglevel=debug --adaptive > thermald_log.log
    ```
2.  **Look at PL1/PL2 at the MSR level**
    Use `rdmsr/wrmsr` to inspect `MSR_PKG_POWER_LIMIT` and related registers.
    ```
    $ sudo apt install msr-tools
    $ sudo modprobe msr

    # MSR address: MSR_PKG_POWER_LIMIT = 0x610 (classic Intel)
    $ sudo rdmsr -p 0 0x610

    # Save the original value of MSR 0x610
    $ sudo rdmsr -p 0 0x610 > original_value.txt

    # Change the value of 0x610
    $ sudo wrmsr -p 0 0x610 <NEW_HEX_VALUE>

    # Watch for 5~30 seconds to see whether it gets written back:
    watch -n 1 "sudo rdmsr -p 0 0x610"
    ```
3.  **Look at the actual power through powercap/rapl**
    *  `/sys/class/powercap/intel-rapl:*`
    * `grep . /sys/class/powercap/intel-rapl:0/constraint_*`
    *  Under load, check whether the average package power converges toward 40W or 20W.
4.  **Compare early i915/KMS loading with the thermald log**
    *   On some platforms, the load timing of the iGPU/telemetry affects whether the power policy takes effect (community experience).
        **Reference**: community reports on Dynamic Tuning and i915/KMS timing. [\[reddit.com\]](https://www.reddit.com/r/linux/comments/u7zxa0/psa_for_intel_tiger_lake_dynamic_tuning_laptops/)

> **Rule of thumb**: if you set the MSR to 20W but the real power under load still converges toward 40W, and the MSR is written back after a while, it is almost certain that **MMIO/firmware (DPTF/DTT/OEM tuning) is in control**.
