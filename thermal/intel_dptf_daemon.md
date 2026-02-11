# Intel DPTF

## Intel DPTF in Linux kernel

根據 Linux kernel 文件對 DPTF 的定義：

> *"DPTF is a platform level hardware/software solution… some parts implemented in firmware using ACPI, kernel drivers expose interfaces to user space"* [\[docs.kernel.org\]](https://docs.kernel.org/driver-api/thermal/intel_dptf.html)

整個 DPTF 架構包含：

    ┌──────────────────────────────┐
    │ Firmware / BIOS               │
    │  - ACPI DPTF tables (_TRT…)   │
    └──────────────┬───────────────┘
                   │
    ┌──────────────▼───────────────┐
    │ Kernel drivers                │
    │  - INT3400 / INTC1040 etc.    │
    │  - thermal / power interfaces│
    └──────────────┬───────────────┘
                   │
    ┌──────────────▼───────────────┐
    │ User space policy engine      │
    │  - ipf_ufd                    │
    │  - DptfPolicy*.so             │
    └──────────────────────────────┘

**GitHub `intel/dptf` 只涵蓋最下面那一層（userspace policy & ESIF framework）**

## GitHub 上的 `intel/dptf`
在 repo README 裡，Intel 自己這樣描述它：

> *"Intel (R) Dynamic Tuning for Chromium OS"*  
> *"DPTF user space daemon relies on INT340X thermal drivers and DPTF ACPI objects"* [\[github.com\]](https://github.com/intel/dptf), [\[github.com\]](https://github.com/intel/dptf/blob/master/README.txt)

重點：

*   它是 **user space daemon / framework**
*   依賴：
    *   **BIOS/firmware 內的 DPTF ACPI objects**
    *   Linux kernel 內的 **INT340x / INTC104x driver**
*   主要目標平台：
    *   **ChromeOS**
    *   **Linux（Ubuntu 等）**

這正好對應到「Intel DPTF 在 Linux/ChromeOS 的 userspace 實作」。

## Intel DPTF vs. dptf userspace framework

*   **概念上的 Intel DPTF**：一個 *平台級的 power / thermal 管理架構與規格*
*   **GitHub `intel/dptf`**：Intel **開源釋出的 DPTF userspace framework 實作**，主要對象是 **Linux / ChromeOS**

> 「GitHub 上的 `intel/dptf` 是 **Intel DPTF 在 Linux / ChromeOS 的開源 userspace 實作**，  
> 屬於整個 Intel DPTF 平台架構中的一個組件，而不是完整的 DPTF 生態。」
