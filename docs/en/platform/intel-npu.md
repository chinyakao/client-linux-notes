---
title: "Intel NPU driver and power measurement"
parent: "Graphics & Platform"
grand_parent: "English"
nav_order: 3
lang: en
---

# Intel NPU: driver setup and CPU / GPU / NPU power measurement

Goal: make the NPU on an Intel Meteor Lake laptop usable from OpenVINO, then measure the speed and power of
the same AI workload on the CPU, the integrated GPU, and the NPU with one method.
The workload is the embedding model and a small LLM from [rag_minimal](https://github.com/chinyakao/rag_minimal);
the benchmark code lives in that repo's `bench/`.

## Stack: from kernel to application

| Layer | Component | Notes |
|---|---|---|
| Application | OpenVINO (`device="NPU"`) | Compiles the model into a blob the NPU runs |
| Compiler | `intel-driver-compiler-npu` | Graph → NPU instructions; first compile is slow, cache it with `CACHE_DIR` |
| User-space driver | `intel-level-zero-npu` + `libze1` | Level Zero API that submits work to the kernel |
| Firmware | `intel-fw-npu` (`/lib/firmware/intel/vpu/`) | Firmware loaded onto the NPU by the driver |
| Kernel driver | `intel_vpu` (`drivers/accel/ivpu/`) | Part of the DRM accel subsystem, creates `/dev/accel/accel0` |

The kernel driver is in mainline; the user-space parts come from the
[intel/linux-npu-driver](https://github.com/intel/linux-npu-driver) releases.

## Setup (Ubuntu 24.04+)

1. Check for kernel 6.8 or newer and the module:
   ```bash
   uname -r
   lsmod | grep intel_vpu
   sudo dmesg | grep -i vpu        # shows the firmware version
   ls -l /dev/accel/accel0
   ```
2. Download the `.deb` packages for your Ubuntu release (compiler, fw, level-zero) and the level-zero loader
   from the intel/linux-npu-driver releases, then install:
   ```bash
   sudo apt install libtbb12
   sudo dpkg -i *.deb
   ```
3. Let a normal user open the NPU:
   ```bash
   sudo usermod -aG render $USER          # log out and back in
   # if accel0 is not owned by the render group, add a udev rule:
   echo 'SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="render", MODE="0660"' \
     | sudo tee /etc/udev/rules.d/10-intel-vpu.rules
   sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=accel
   ```
4. Check that OpenVINO sees it:
   ```bash
   pip install openvino
   python -c "import openvino as ov; print(ov.Core().available_devices)"   # ['CPU', 'GPU', 'NPU']
   ```

All checks in one script: [`tools/npu/check_npu.sh`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/check_npu.sh).

## How to measure power

| Source | Path / tool | What it measures | Caveats |
|---|---|---|---|
| RAPL package | `/sys/class/powercap/intel-rapl:0/energy_uj` | Cumulative energy of the whole SoC (CPU + iGPU + NPU) | Root-only by default; the counter wraps |
| turbostat | `PkgWatt` `CorWatt` `GFXWatt` | Average package, CPU core, and GPU power | Needs root; no separate NPU column |
| NPU busy time | `/sys/class/accel/accel0/device/npu_busy_time_us` | Cumulative time the NPU was working → utilization | Only on newer kernels |

On Meteor Lake the NPU sits on the SoC tile and RAPL has no NPU domain, so:

- **Compare package power**: run the same job on CPU, GPU, and NPU, compare `PkgWatt`, and subtract idle power.
- **Compare energy efficiency**: joules per chunk or per token (J/chunk, J/token) is fairer than watts alone,
  because a faster device can draw more power yet use less energy in total.
- **Use NPU busy time to confirm the job really ran on the NPU**: utilization should rise and CPU `Busy%` should stay low.

[`tools/npu/measure_power.sh`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/measure_power.sh)
records an idle baseline, runs any command while logging turbostat and NPU busy time, then prints average power
and energy above idle:

```bash
sudo ./tools/npu/measure_power.sh -- python bench/bench_embed.py --devices NPU
```

## Variables to control

- Plug in AC, fix the power profile (for example `powerprofilesctl set performance`, or balanced for every run), close other apps.
- Cool down between devices so the previous run's temperature does not affect the next run's turbo.
- The NPU only takes static shapes, so all three devices use the same `[batch, seq_len]` for a fair comparison.
- The first compile (especially on the NPU) is slow; record cold compile time and cached compile time separately.
- Check results stay the same: embedding cosine vs PyTorch should be close to 1, and `eval.py` hit@3 should not drop.

## Results

Not measured yet; will be added after the runs.
