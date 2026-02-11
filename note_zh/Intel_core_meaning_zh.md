# Intel CPU Core & BIOS setup menu
## 3 Types of Core

### P-core（Performance Core）
  - 高效能、單核能力強
  - 用於遊戲主線程、重度工作
  - 功耗高、支援 Hyper‑Threading

### E-core（Efficiency Core）
  - 效率核心，用於背景工作、多工
  - 每瓦效能高、不支援超執行緒
  - 放在 CPU die（Compute tile）

### LP E-core / Atom（Low Power Efficiency Core）
  - 超低功耗核心
  - 用於筆電的待機、Always‑On、喚醒
  - 放在 SoC die（SoC tile）
  - 不用來跑重度工作

## CPU die vs SoC die
兩者都是“核心”，但用途完全不同。
| Die (Tile) | 會出現的核心類型 | 用途 |
| ------------- | ------------- | ------------- |
| CPU die / Compute tile | P‑cores、E‑cores | 一般運算、遊戲、多工 |
| SoC die / SoC tile | LP E‑cores / Atom cores | 待機、背景、節能系統維持 |

## BIOS Setup 的名稱與實際對應
In BIOS Setup Menu:
  - active soc-north efficient-cores
  - disable soc E-cores
  - disable soc-south E-cores

指的是 SoC die 上的 LP E-core / Atom 的群組開關（cluster control）不是 CPU E-core（Compute tile 上的 E-core）

Intel 會把 SoC 上的 LP E-core 分成 north / south cluster，提供 BIOS 單獨啟用或關閉。

## 關掉的影響（快速參考）
### 關 SoC LP E-core（Atom）可能影響：
  - 待機耗電上升
  - 睡眠喚醒變慢
  - 語音喚醒 / Always-On 功能失效
  - 筆電續航變差
  - 但：對遊戲或工作效能幾乎 沒有幫助

### 關 CPU E-core（Compute tile）影響：
  - 多工下降
  - 瀏覽器與背景工作變慢
  - 某些遊戲可能更穩定（少數特例）
