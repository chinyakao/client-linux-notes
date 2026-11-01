---
title: Home
nav_order: 1
---

# Linux Training

Notes from my work as a Linux platform engineer: bringing up Ubuntu on laptops,
desktops, and all-in-ones, and debugging kernel, driver, power, thermal, and
graphics issues. Pages marked in Chinese (中文) are written in Traditional Chinese.

| Section | What's inside |
|---|---|
| [Kernel Build](kernel-build/index.md) | Docker-based builds for mainline, drm-tip, kernel.org, and Ubuntu OEM kernels; producing installable `.deb` test kernels; patches, configs, tmux. |
| [Power Management](power/index.md) | s2idle vs. S0ix vs. S3, `/sys/power/mem_sleep`, rtcwake, cpuidle and C-states. |
| [Thermal](thermal/index.md) | The Linux thermal stack from ACPI DPTF tables to thermald, PL1/PL2 power limits, and a staged thermal stress test. |
| [Graphics & Platform](platform/index.md) | Intel iGPU fullscreen FPS drop troubleshooting, Intel core types and BIOS options. |
| [Debugging](debugging/index.md) | Kernel panic, apport, core dumps. |

## Related

- [linux-device-driver](https://github.com/chinyakao/linux-device-driver): kernel drivers written from scratch, tested in QEMU.
- [linux_tool_script](https://github.com/chinyakao/linux_tool_script): stress and log collection scripts (suspend residency, network reboot).
- [fwupd](https://github.com/fwupd/fwupd): upstream contributions to the `mediatek-scaler` plugin (released in 1.9.31 and 2.0.13).
