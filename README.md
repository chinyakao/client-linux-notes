# Linux Platform Enablement Notes

Notes, scripts, and build environments for Linux platform work, collected from
what I used and learned on the job.

**Read it as a website: <https://chinyakao.github.io/linux-platform-enablement/>**

## Layout

| Path | What's inside |
|---|---|
| [`docs/`](docs/) | All notes, published with GitHub Pages in English ([`docs/en/`](docs/en/)) and Traditional Chinese ([`docs/zh/`](docs/zh/)): kernel build, power management, thermal, graphics, debugging. |
| [`kernel_builder/`](kernel_builder/) | Dockerfiles and kernel configs for mainline, kernel.org archives, Torvalds upstream, Intel drm-tip, and Ubuntu OEM 6.14 / 6.17. |
| [`tools/thermal/thermal_stress_test.sh`](tools/thermal/thermal_stress_test.sh) | Staged CPU load while logging thermal zones, cooling devices, cpufreq, turbostat, and thermald to CSV. |
| [`tools/thermal/analyze_compare.py`](tools/thermal/analyze_compare.py) | Summarizes one stress test run or compares two. |

Every note exists at the same path under `docs/en/` and `docs/zh/`; the site links each page to its translation.

## Related repositories

- [linux-device-driver](https://github.com/chinyakao/linux-device-driver): kernel drivers written from scratch, plus the earlier driver exercises that used to live here.
- [linux_tool_script](https://github.com/chinyakao/linux_tool_script): stress and log-collection scripts (suspend/s2idle residency, network reboot).
- [fwupd](https://github.com/fwupd/fwupd): upstream contributions to the `mediatek-scaler` plugin (released in 1.9.31 and 2.0.13).

## Publishing the site

Settings → Pages → Source: *Deploy from a branch*, Branch: `main`, folder `/docs`.
