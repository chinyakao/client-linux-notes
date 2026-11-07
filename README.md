# Client Linux Notes

My study notes on Linux for laptops and desktops, with the scripts and build
environments I wrote while learning.

**Read it as a website: <https://chinyakao.github.io/client-linux-notes/>**

## Layout

| Path | What's inside |
|---|---|
| [`docs/`](docs/) | All notes, published with GitHub Pages in English ([`docs/en/`](docs/en/)) and Traditional Chinese ([`docs/zh/`](docs/zh/)): kernel build, power management, thermal, graphics, debugging. |
| [`kernel_builder/`](kernel_builder/) | Dockerfiles and kernel configs for mainline, kernel.org archives, Torvalds upstream, Intel drm-tip, and Ubuntu OEM 6.14 / 6.17. |
| [`tools/thermal/thermal_stress_test.sh`](tools/thermal/thermal_stress_test.sh) | Staged CPU load while logging thermal zones, cooling devices, cpufreq, turbostat, and thermald to CSV. |
| [`tools/thermal/analyze_compare.py`](tools/thermal/analyze_compare.py) | Summarizes one stress test run or compares two. |
| [`tools/npu/check_npu.sh`](tools/npu/check_npu.sh) | Checks the Intel NPU stack: `intel_vpu`, `/dev/accel/accel0` permissions, firmware, user-space packages, OpenVINO devices. |
| [`tools/npu/measure_power.sh`](tools/npu/measure_power.sh) | Runs any command while logging turbostat power and NPU busy time, with an idle baseline. |

Every note exists at the same path under `docs/en/` and `docs/zh/`; the site links each page to its translation.

## Related repositories

- [rag_minimal](https://github.com/chinyakao/rag_minimal): the RAG workload used for the CPU / GPU / NPU comparison (`bench/`).
- [linux-device-driver](https://github.com/chinyakao/linux-device-driver): kernel drivers written from scratch, plus the earlier driver exercises that used to live here.
- [linux_tool_script](https://github.com/chinyakao/linux_tool_script): stress and log-collection scripts (suspend/s2idle residency, network reboot).
- [fwupd](https://github.com/fwupd/fwupd): upstream contributions to the `mediatek-scaler` plugin (released in 1.9.31 and 2.0.13).

## Publishing the site

Settings → Pages → Source: *Deploy from a branch*, Branch: `main`, folder `/docs`.
