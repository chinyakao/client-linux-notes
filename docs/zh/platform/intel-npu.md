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

## 結果（2026-11-06，embedding）

環境：Meteor Lake 筆電（Core Ultra 7 155H，iGPU，NPU），Ubuntu，kernel 7.0，接電源。
工作負載：[rag_minimal](https://github.com/chinyakao/rag_minimal) 的 `paraphrase-multilingual-MiniLM-L12-v2`，
資料是 Ubuntu linux-oem-7.0 kernel changelog（18 個版本，3588 個 chunk）。
OpenVINO 固定輸入 `[8, 128]`（查詢延遲用 `[1, 128]`），每項至少跑 10 秒。指令：`sudo -E python bench/bench_embed.py`。

| 裝置 | 建索引 chunks/s | 相對 PyTorch | 查詢 p50 / p95 (ms) | Package 功率 (W) | CPU core 功率 (W) | J/chunk（扣閒置） | NPU 使用率 |
|---|---|---|---|---|---|---|---|
| PyTorch CPU（基準） | 48.8 | 1.0x | 12.2 / 13.9 | 43.0 | 35.4 | 0.83 | 0% |
| OpenVINO CPU | 40.7 | 0.83x | 24.7 / 34.1 | 32.3 | 27.9 | 0.73 | 0% |
| OpenVINO GPU | **299.2** | **6.1x** | 12.3 / 13.5 | 26.4 | 1.9 | 0.080 | 0% |
| OpenVINO NPU | 113.9 | 2.3x | **7.6 / 8.8** | **9.6** | 0.7 | **0.062** | 94% |

閒置 package 功率 2.6 W。四個裝置輸出的向量與 PyTorch 的 cosine 都是 1.000。

準確度（`eval.py --oem`，20 題 kernel 題庫）：PyTorch 索引與 NPU 索引的 hit@3 都是 **13/18 = 0.72**，每題命中結果相同。

**結論**

- **吞吐量 GPU 最快**：大量建索引時 GPU 是 PyTorch CPU 的 6 倍。
- **NPU 最省電、單筆延遲最低**：package 功率只有 9.6 W，是 GPU 的約 1/3、CPU 的約 1/4；扣掉閒置後每個 chunk 的能量比 GPU 少約 22%，比 CPU 少約 13 倍。
- **工作真的在 NPU 上**：NPU 使用率 94%，同時 CPU core 功率只有 0.7 W。
- **換裝置不影響準確度**：向量幾乎一樣，hit@3 完全相同。
- OpenVINO CPU 反而比 PyTorch 慢，可能是固定補到 128 token（PyTorch 只補到該 batch 最長）以及預設的延遲模式，待查。

原始資料：[`tools/npu/results/embed_20261106_161532.jsonl`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/results/embed_20261106_161532.jsonl)。

**限制**：只量一次；只測 batch 8；`compile_s` 是有快取後的時間（冷啟動另測）。

## 結果（2026-11-06，小型 LLM）

模型：Qwen2.5-1.5B-Instruct，`optimum-cli` 轉成 int4（對稱、channel-wise），三個裝置用同一份。
工作負載：3 個 kernel 問題，每題用 rag_minimal 檢索出的 RAG prompt（平均 781 個輸入 token），固定生成 128 個 token，每題跑 2 次。
指令：`sudo -E python bench/bench_llm.py --model ov_models/qwen2.5-1.5b-int4`。

| 裝置 | 第一個 token（TTFT） | 之後每秒 token | 每題總時間 | Package 功率 (W) | 每題能量（扣閒置） | NPU 使用率 |
|---|---|---|---|---|---|---|
| CPU | 2.61 s | **41.6** | 5.7 s | 30.5 | 155 J | 0% |
| GPU | **0.50 s** | 33.7 | **4.3 s** | 21.8 | 79 J | 0% |
| NPU | 1.85 s | 21.6 | 7.7 s | **12.2** | **69 J** | 97% |

每題總時間 = TTFT + 127 × 每個 token 的時間。閒置 package 功率 3.3 W。

**結論**

- **讀 prompt（prefill）GPU 最快**：781 個 token 一次平行算完，GPU 比 NPU 快 3.7 倍、比 CPU 快 5 倍。
- **逐字生成（decode）CPU 最快**：每個 token 都要把整個模型從記憶體讀一次，瓶頸是記憶體頻寬，不是算力。
- **整體回答時間 GPU 最短**；NPU 最慢，但功率只有 GPU 的 56%。
- **能量：NPU 和 GPU 接近**（扣閒置後 NPU 少約 13%），兩者都只有 CPU 的一半左右。
- 回答品質：1.5B 模型的回答在 CVE 題目上前後矛盾、輸出簡體中文；這份量測只比速度與功耗。

原始資料：[`tools/npu/results/llm_20261106_170440.jsonl`](https://github.com/chinyakao/linux-platform-enablement/blob/main/tools/npu/results/llm_20261106_170440.jsonl)。

## 總結：什麼工作交給哪個晶片

| 工作 | 建議 | 原因 |
|---|---|---|
| 一次建大量索引 | GPU | 吞吐量是 NPU 的 2.6 倍 |
| 一問一答的查詢 embedding | NPU | 最快（7.6 ms）且功率最低 |
| LLM 生成回答，要快 | GPU | prefill 快，總時間最短 |
| LLM 生成回答，要省電、背景執行 | NPU | 功率最低，不佔用 CPU 和 GPU |
