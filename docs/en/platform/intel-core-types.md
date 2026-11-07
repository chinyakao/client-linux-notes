---
title: "Intel P/E/LP E-cores"
parent: "Graphics & Platform"
grand_parent: "English"
nav_order: 2
lang: en
---

# Intel CPU Core Types
## 3 Types of Core

### P-core (Performance Core)
  - High performance, strong single-core performance
  - Used for game main threads and heavy work
  - High power, supports Hyper‑Threading

### E-core (Efficiency Core)
  - Efficiency core for background work and multitasking
  - High performance per watt, no Hyper-Threading
  - Located on the CPU die (Compute tile)

### LP E-core / Atom (Low Power Efficiency Core)
  - Ultra-low-power core
  - Used for laptop standby, Always‑On, and wake-up
  - Located on the SoC die (SoC tile)
  - Not used for heavy work

## CPU die vs SoC die
Both are "cores", but their purposes are completely different.

| Die (Tile) | Core types on it | Purpose |
| ------------- | ------------- | ------------- |
| CPU die / Compute tile | P‑cores, E‑cores | General computing, games, multitasking |
| SoC die / SoC tile | LP E‑cores / Atom cores | Standby, background, keeping the system alive at low power |
