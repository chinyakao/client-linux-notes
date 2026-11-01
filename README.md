# Linux Training

Notes, scripts, and build environments from my work as a Linux platform engineer
(Ubuntu enablement on Dell laptops, desktops, and all-in-ones).

**Read it as a website: <https://chinyakao.github.io/linux_training/>**

## Layout

| Path | What's inside |
|---|---|
| [`docs/`](docs/) | All notes, published with GitHub Pages: kernel build, power management, thermal, graphics, debugging. |
| [`kernel_builder/`](kernel_builder/) | Dockerfiles and kernel configs for mainline, kernel.org archives, Torvalds upstream, Intel drm-tip, and Ubuntu OEM 6.14 / 6.17. |
| [`thermal_stress_test.sh`](thermal_stress_test.sh) | Staged CPU load while logging thermal zones, cooling devices, cpufreq, turbostat, and thermald to CSV. |
| [`analyze_compare.py`](analyze_compare.py) | Summarizes one stress test run or compares two. |

Files ending in `_zh.md` are in Traditional Chinese.

## Related repositories

- [linux-device-driver](https://github.com/chinyakao/linux-device-driver): kernel drivers written from scratch, plus the earlier driver exercises that used to live here.
- [linux_tool_script](https://github.com/chinyakao/linux_tool_script): stress and log-collection scripts (suspend/s2idle residency, network reboot).
- [fwupd](https://github.com/fwupd/fwupd): upstream contributions to the `mediatek-scaler` plugin (released in 1.9.31 and 2.0.13).

## Publishing the site

Settings → Pages → Source: *Deploy from a branch*, Branch: `main`, folder `/docs`.
