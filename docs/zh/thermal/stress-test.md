---
title: "散熱壓力測試"
parent: "散熱"
grand_parent: "中文"
nav_order: 5
lang: zh
---

# 散熱壓力測試

Repo 根目錄有兩個腳本，用來量測平台的升溫與降溫行為，並比較兩次測試（例如兩個 BIOS 版本）。

## thermal_stress_test.sh

[原始碼](https://github.com/chinyakao/client-linux-notes/blob/main/tools/thermal/thermal_stress_test.sh)

用 `stress-ng` 分階段加壓，每個間隔記錄：

| 檔案 | 內容 |
|---|---|
| `thermal_zones.csv` | 每個 thermal zone 的溫度與 trip point |
| `cooling_devices.csv` | 每個 cooling device 的目前與最大 state |
| `cpufreq.csv` | 每個 policy 的目前、最小、最大頻率與 governor |
| `turbostat.csv` | Package 功耗與 C-state（有安裝 turbostat 時） |
| `thermald_journal.log` | 這次測試期間的 thermald log |

預設階段（名稱、秒數、CPU 負載 %）：warmup 300 60、cross 300 90、sustain 600 90、cooldown 180 0。

```bash
sudo apt-get install -y stress-ng linux-tools-common linux-tools-generic
sudo OUT_ROOT=./logs INTERVAL=1 CPU_WORKERS=8 ./tools/thermal/thermal_stress_test.sh
```

## analyze_compare.py

[原始碼](https://github.com/chinyakao/client-linux-notes/blob/main/tools/thermal/analyze_compare.py)

整理一次測試的摘要（最熱的 zone、cooling state 最高值、最低 CPU 頻率），或比較兩次測試。

```bash
python3 tools/thermal/analyze_compare.py logs/runA [logs/runB]
```
