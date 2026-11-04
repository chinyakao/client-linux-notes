---
title: "Intel NPU 驅動與功耗量測"
parent: "顯示與平台"
grand_parent: "中文"
nav_order: 3
lang: zh
---

# Intel NPU：驅動安裝與 CPU / GPU / NPU 功耗量測

目標：在 Intel Meteor Lake 筆電上讓 NPU 可以被 OpenVINO 使用，並用同一套方法量
CPU、內顯（GPU）、NPU 跑 AI 工作負載的速度與功耗。
實際跑的工作負載是 [rag_minimal](https://github.com/chinyakao/rag_minimal) 的 embedding 模型與小型 LLM，
benchmark 程式在該 repo 的 `bench/`。

## 架構：NPU 從 kernel 到應用程式

| 層 | 元件 | 說明 |
|---|---|---|
| 應用 | OpenVINO（`device="NPU"`） | 把模型編譯成 NPU 可執行的 blob |
| 編譯器 | `intel-driver-compiler-npu` | 模型圖 → NPU 指令，第一次編譯很久，可用 `CACHE_DIR` 快取 |
| User-space 驅動 | `intel-level-zero-npu` + `libze1` | Level Zero API，送工作給 kernel |
| 韌體 | `intel-fw-npu`（`/lib/firmware/intel/vpu/`） | NPU 上的韌體，開機時由驅動載入 |
| Kernel 驅動 | `intel_vpu`（`drivers/accel/ivpu/`） | 屬於 DRM accel 子系統，產生 `/dev/accel/accel0` |

kernel 驅動已經在 mainline，user-space 部分來自
[intel/linux-npu-driver](https://github.com/intel/linux-npu-driver) 的 Release。

## 安裝（Ubuntu 24.04+）

1. 確認 kernel 6.8 以上，模組已載入：
   ```bash
   uname -r
   lsmod | grep intel_vpu
   sudo dmesg | grep -i vpu        # 會看到韌體版本
   ls -l /dev/accel/accel0
   ```
2. 從 intel/linux-npu-driver 的 Release 下載對應 Ubuntu 版本的 `.deb`（compiler、fw、level-zero）以及 level-zero loader，安裝：
   ```bash
   sudo apt install libtbb12
   sudo dpkg -i *.deb
   ```
3. 讓一般帳號可以用 NPU：
   ```bash
   sudo usermod -aG render $USER          # 之後要重新登入
   # 若 accel0 的群組不是 render，加 udev 規則：
   echo 'SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="render", MODE="0660"' \
     | sudo tee /etc/udev/rules.d/10-intel-vpu.rules
   sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=accel
   ```
4. 驗證 OpenVINO 看得到 NPU：
   ```bash
   pip install openvino
   python -c "import openvino as ov; print(ov.Core().available_devices)"   # ['CPU', 'GPU', 'NPU']
   ```

一次檢查全部：[`tools/npu/check_npu.sh`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/check_npu.sh)。

## 功耗怎麼量

| 來源 | 路徑 / 工具 | 量到什麼 | 注意 |
|---|---|---|---|
| RAPL package | `/sys/class/powercap/intel-rapl:0/energy_uj` | 整顆 SoC（CPU + iGPU + NPU）累積能量 | 預設只有 root 可讀；計數器會溢位繞回 |
| turbostat | `PkgWatt` `CorWatt` `GFXWatt` | package、CPU 核心、GPU 的平均功率 | 需要 root；沒有獨立的 NPU 功率欄位 |
| NPU busy time | `/sys/class/accel/accel0/device/npu_busy_time_us` | NPU 實際工作的累積時間 → 使用率 | 較新的 kernel 才有 |

Meteor Lake 的 NPU 在 SoC tile 上，RAPL 沒有單獨的 NPU domain，所以做法是：

- **比 package 功率**：同一個工作分別在 CPU、GPU、NPU 上跑，比 `PkgWatt`，並扣掉閒置功耗。
- **比能量效率**：每個 chunk 或每個 token 花多少焦耳（J/chunk、J/token），比單看瓦數更公平，因為跑得快的裝置雖然瓦數高，但總能量可能較少。
- **用 NPU busy time 確認工作真的在 NPU 上**：跑 NPU 時使用率應明顯上升，CPU `Busy%` 應該不高。

[`tools/npu/measure_power.sh`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/measure_power.sh)
會先量一段閒置，再執行任意指令，同時記錄 turbostat 與 NPU busy time，最後印出平均功率與高於閒置的能量：

```bash
sudo ./tools/npu/measure_power.sh -- python bench/bench_embed.py --devices NPU
```

## 量測時要控制的變因

- 接上電源，固定電源模式（例如 `powerprofilesctl set performance` 或全部用 balanced），關掉其他程式。
- 每個裝置之間冷卻幾秒，避免前一個測試的溫度影響下一個的 turbo。
- NPU 只吃靜態形狀，所以三個裝置都用相同的 `[batch, seq_len]`，比較才公平。
- 第一次編譯（尤其 NPU）很久，要分開記「冷啟動編譯時間」與「快取後」。
- 確認換裝置後結果一致：embedding 和 PyTorch 版本的 cosine 應接近 1，`eval.py` 的 hit@3 不應變差。

## 結果

尚未量測，實測後補上。
