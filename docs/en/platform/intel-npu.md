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

## Results (2026-11-06, embedding)

Setup: Meteor Lake laptop (Core Ultra 7 155H, iGPU, NPU), Ubuntu, kernel 7.0, on AC power.
Workload: `paraphrase-multilingual-MiniLM-L12-v2` from [rag_minimal](https://github.com/chinyakao/rag_minimal),
over the Ubuntu linux-oem-7.0 kernel changelog (18 versions, 3588 chunks).
OpenVINO uses a fixed `[8, 128]` input (`[1, 128]` for query latency); each measurement runs at least 10 s.
Command: `sudo -E python bench/bench_embed.py`.

| Device | Index chunks/s | vs PyTorch | Query p50 / p95 (ms) | Package power (W) | CPU core power (W) | J/chunk (above idle) | NPU util |
|---|---|---|---|---|---|---|---|
| PyTorch CPU (baseline) | 48.8 | 1.0x | 12.2 / 13.9 | 43.0 | 35.4 | 0.83 | 0% |
| OpenVINO CPU | 40.7 | 0.83x | 24.7 / 34.1 | 32.3 | 27.9 | 0.73 | 0% |
| OpenVINO GPU | **299.2** | **6.1x** | 12.3 / 13.5 | 26.4 | 1.9 | 0.080 | 0% |
| OpenVINO NPU | 113.9 | 2.3x | **7.6 / 8.8** | **9.6** | 0.7 | **0.062** | 94% |

Idle package power is 2.6 W. Every device's vectors match PyTorch with cosine 1.000.

Accuracy (`eval.py --oem`, 20 kernel questions): hit@3 is **13/18 = 0.72** for both the PyTorch index and the NPU index, with identical hits per question.

**Takeaways**

- **GPU has the highest throughput**: 6x PyTorch CPU for bulk indexing.
- **NPU has the lowest power and the lowest single-query latency**: 9.6 W package power, about 1/3 of the GPU and 1/4 of the CPU; energy per chunk above idle is about 22% lower than the GPU and about 13x lower than the CPU.
- **The work really runs on the NPU**: 94% NPU utilization while CPU core power stays at 0.7 W.
- **Switching devices does not change accuracy**: the vectors are effectively identical and hit@3 is the same.
- OpenVINO CPU is slower than PyTorch, likely because it always pads to 128 tokens (PyTorch pads to the longest in the batch) and uses the default latency hint; still to check.

Raw data: [`tools/npu/results/embed_20261106_161532.jsonl`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/results/embed_20261106_161532.jsonl).

**Limits**: single run; batch 8 only; `compile_s` is with a warm cache (cold start not measured yet).

## Results (2026-11-06, small LLM)

Model: Qwen2.5-1.5B-Instruct, converted to int4 (symmetric, channel-wise) with `optimum-cli`; the same files on all three devices.
Workload: 3 kernel questions, each with the RAG prompt retrieved by rag_minimal (781 input tokens on average), a fixed 128 output tokens, 2 runs per question.
Command: `sudo -E python bench/bench_llm.py --model ov_models/qwen2.5-1.5b-int4`.

| Device | First token (TTFT) | Tokens/s after that | Time per answer | Package power (W) | Energy per answer (above idle) | NPU util |
|---|---|---|---|---|---|---|
| CPU | 2.61 s | **41.6** | 5.7 s | 30.5 | 155 J | 0% |
| GPU | **0.50 s** | 33.7 | **4.3 s** | 21.8 | 79 J | 0% |
| NPU | 1.85 s | 21.6 | 7.7 s | **12.2** | **69 J** | 97% |

Time per answer = TTFT + 127 × time per token. Idle package power is 3.3 W.

**Takeaways**

- **The GPU is fastest at reading the prompt (prefill)**: 781 tokens in parallel, 3.7x faster than the NPU and 5x faster than the CPU.
- **The CPU is fastest at generating token by token (decode)**: each token reads the whole model from memory, so memory bandwidth, not compute, is the limit.
- **The GPU gives the shortest answer time**; the NPU is slowest but draws 56% of the GPU's power.
- **Energy: NPU and GPU are close** (about 13% less on the NPU above idle), both about half of the CPU.
- Answer quality: the 1.5B model contradicts itself on the CVE question and answers in Simplified Chinese; this run only compares speed and power.

Raw data: [`tools/npu/results/llm_20261106_170440.jsonl`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/results/llm_20261106_170440.jsonl).

## Summary: which job goes to which chip

| Job | Use | Why |
|---|---|---|
| Building a large index at once | GPU | 2.6x the NPU's throughput |
| Embedding a single query | NPU | Fastest (7.6 ms) and lowest power |
| LLM answers, as fast as possible | GPU | Fast prefill, shortest total time |
| LLM answers, low power or in the background | NPU | Lowest power, leaves CPU and GPU free |
