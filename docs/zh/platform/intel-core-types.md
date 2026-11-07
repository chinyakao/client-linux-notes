---
title: "Intel P/E/LP E-core"
parent: "顯示與平台"
grand_parent: "中文"
nav_order: 2
lang: zh
---

# Intel CPU Core Types
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
