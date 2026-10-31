# Linux Training

Notes, scripts, and build environments from my work as a Linux platform engineer
(Ubuntu enablement on Dell laptops, desktops, and all-in-ones).

## Contents

| Area | What's inside |
|---|---|
| [`kernel_builder/`](kernel_builder/) | Docker-based kernel build environments for mainline, kernel.org archives, Torvalds upstream, Intel drm-tip, and Ubuntu OEM 6.14 / 6.17. Each produces installable `.deb` packages for test kernels and bisects. |
| [`thermal/`](thermal/) | The Linux thermal stack from ACPI DPTF tables to thermald; Intel DPTF vs. DTT vs. thermald; how PL1/PL2 power limits are really decided (MSR vs. MMIO). |
| [`thermal_stress_test.sh`](thermal_stress_test.sh) | Staged CPU load (warmup → cross → sustain → cooldown) while logging thermal zones, cooling devices, cpufreq, turbostat, and the thermald journal to CSV. |
| [`analyze_compare.py`](analyze_compare.py) | Summarizes one run of the stress test, or compares two runs (for example, two BIOS versions). |
| [`graphic/`](graphic/) | Intel iGPU troubleshooting: confirming i915 binding and tracking down a fullscreen 60 → 30 FPS drop (PSR, DRRS, GuC/HuC). |
| [`note/`](note/) | Power management (s2idle / S0ix / S3, cpuidle), crash handling (kernel panic, apport, core dump), Intel core types, and build tooling (git patches, `bindeb-pkg`, Docker, tmux). |
| [`kernel_driver/`](kernel_driver/) | Kernel module exercises. See its README for what is finished and what is planned. |

Files ending in `_zh.md` are Traditional Chinese versions.

## Related repositories

- [linux_tool_script](https://github.com/chinyakao/linux_tool_script): stress and log-collection scripts (suspend/s2idle residency, network reboot).
- [linux-device-driver](https://github.com/chinyakao/linux-device-driver): driver side projects written from scratch.
- [fwupd](https://github.com/fwupd/fwupd): upstream contributions to the `mediatek-scaler` plugin (released in 1.9.31 and 2.0.13).
