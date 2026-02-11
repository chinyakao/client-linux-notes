# Linux Thermal Framework
```
──────────────────────────────────────────────
[ Layer 4: User Space ]
    • thermald (basic cooling daemon) 
    • dptfxtract (讀 ACPI 表, this tool is archived) 
    • (Windows/ChromeOS 有 ESIF + Policy Manager，Ubuntu 沒有) 
──────────────────────────────────────────────
[ Layer 3: OS Kernel Level ]
    • Linux Thermal Framework
    • INT340x DPTF drivers (讀 ACPI DPTF 表) 
    • intel_rapl / powercap (RAPL subsystem)
    • cpufreq / intel_pstate
──────────────────────────────────────────────
[ Layer 2: Platform Power Control (MMIO level) (firmware runtime)]
    • Intel SoC / PCH / EC 主導
    • MMIO RAPL Power Limits (可覆寫 OS 設定) 
    • DPTF / DTT runtime 控制 
──────────────────────────────────────────────
[ Layer 1: Firmware / ACPI tables (OEM/BIOS) (firmware static)]
    • DPTF ACPI tables:
        - PSVT (Passive Policy Table)
        - PPCC (Power/Performance Capabilities)
        - ART / TRT (熱關係)
        - Virtual sensors
    • OEM tuning: PL1/PL2 limits, skin temp, chassis temp
    • RAPL defaults (via MSR/MMIO)
    → 這裡會存 policy table e.g., optimized‑28h  
──────────────────────────────────────────────
[ Layer 0: Hardware / Sensors ]
    • CPU thermal sensor / DTS
    • GPU / PCH / Memory sensors
    • Power rails / RAPL energy counters
──────────────────────────────────────────────
```

## Intel DPTF vs. Intel DTT vs. thermald
1. **Linux Thermal Framework Kernel 原生的熱管理架構**  
    thermal zone、cooling device、trip point 等。各家 SoC/CPU 以 driver 接入這個框架  
    例：TI 就示範如何在 Linux 上用 thermal framework 做 DFS/被動降溫  
    來源：TI 應用筆記、Linux Thermal 生態說明  
    參考：TI App Note (Linux Thermal Framework 節)  [\[ti.com\]](https://www.ti.com/lit/an/sdaa069/sdaa069.pdf?ts=1769136051597)  

2. **Intel DPTF (Dynamic Platform and Thermal Framework)**      
    **平台層級的溫控與功耗管理 Framework (主要用在 Windows，少部分 Linux)**
    - 時代背景：DPTF 出現最早，應對 Ultrabook 及低功耗平台的散熱需求
    - OS 介面：主要在 Windows，部分功能透過 ACPI 也可支援 Linux
    - 核心概念：
        - 透過 ACPI 表格 (DPTF table) 描述平台各種溫度節點 (sensor) 與 cooling device
        - 調整 CPU / GPU / 平台功耗、風扇、skin temperature
        - 屬於 firmware 定義 → OS 配合的方式
        - Linux 端有 **INT340x** 等驅動把它們暴露在 sysfs，讓 userspace (如 thermald) 可讀取
    - 運作層級：Firmware + OS (ACPI/Microsoft 的 driver)   
    → DPTF 是一個完整框架：規格 + BIOS/firmware + driver  
    **參考**：Linux kernel 官方 DPTF 介面文件；DPTF 在 Linux/ChromeOS 的整合概述。    [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

3. **Intel DTT (Dynamic Tuning Technology, Adaptix 家族)**  
    **新一代 Telemetry + Thermal Framework，屬於 DPTF 的「下一世代更新」**  
    - 目的：
        - 取代傳統 DPTF 的 ACPI 機制
        - 引入更彈性的 Telemetry (不只溫度，還可收集平台各項數據) 
        - Intel 的 **Runtime Tunner** 技術 (多在 Windows/OEM 端) 
        - 會動態改變 turbo/PL 限制、甚至作 RF 干擾緩解
        - 與 Windows 11/新硬體平台整合得更緊密, Linux 沒有完整官方 DTT framework
    - 架構差異：
        - 從 ACPI-based 轉向使用 Intel Telemetry Hub
        - 更著重於「資料傳輸」「AI-based policy tuning」「OEM 可客製化」
    - OS 支援：主要針對 Windows 10/11，Linux 支援尚不如 Windows 完整  
    → DTT 可以視為 DPTF 的後繼者，但更側重 Telemetry 與資料驅動的政策 (policy) 調整  
    **參考**：Intel/廠商導讀與技術說明。    [\[novintrades.com\]](https://www.novintrades.com/articles/5372?title=intel-dynamic-tuning-technology-complete-guide-practical-how-to), [\[mundobytes.com\]](https://mundobytes.com/en/What-is-Intel-DTT-Dynamic-Tuning-and-how-does-it-relate-to-APO/), [\[dell.com\]](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=853yk)

4. **thermald (Intel Thermal Daemon)**  
    **Intel 官方為 Linux 推出的溫控 daemon**  
    - 平台：Linux 專用
    - 目的：
        - 使用 Linux 的 thermal subsystem (/sys/class/thermal) 
        - 開源使用者空間 daemon，讀取 sysfs/ACPI/DPTF 表，做基礎被動/主動降溫 (如降頻、拉風扇、powerclamp) 
        - 動態調整 CPU frequency、power capping、風扇
        - 讓 Linux 能在 Intel CPU 平台上更有效散熱
        - **不是** DPTF 的完整 policy engine
    - 運作方式：
        - 讀取 Linux Thermal layer 的被動裝置 (passive) 與主動裝置 (active) 
        - 根據溫度制定 cooling action
        - 可以利用 MSR、RAPL 等方式控制 CPU  
    → thermald 是 Linux 的 userspace daemon，不依賴 DPTF，不依賴 DTT，是獨立的 Linux 解決方案。
    - Ubuntu 使用 **thermald 能做的**  
        - 監控 thermal zone (/sys/class/thermal) 
        - 能讀 ACPI DPTF tables (如 PSVT: optimized‑28h)
        - 能做 passive cooling：降頻 (cpufreq/intel\_pstate) 、風扇、powerclamp
        - 但 **無法執行 DPTF 的完整 policy (Adaptive Performance, Power Boss…)**  
    - Ubuntu 使用 **thermald 做不到的(或不完整)**  
        - **ESIF/Policy Manager** 全功能 (如 Adaptive Performance、Power Boss、Virtual Sensor、Cooling Mode 等) 
        - 平臺級 **PL1/PL2/Tau** 策略協同 (尤其是 MMIO/EC/Charger/GPU/Battery 聯動)  
        → thermald 可能嘗試依 optimized‑28h 把 PL1 降成 20W  
        → 但 **平台 MMIO 層可能把 PL1 改回 40W** (見下一段)   
      
    **參考**：thermald 專案 README、kernel 對 DPTF sysfs 的說明。    [\[github.com\]](https://github.com/intel/thermal_daemon), [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html)

5. Table  
    | 項目   | Intel DPTF                   | Intel DTT                         | thermald                        |
    | ---- | ---------------------------- | --------------------------------- | ------------------------------- |
    | 主要平台 | Windows (Linux 支援有限)           | Windows 10/11                     | Linux                           |
    | 性質   | ACPI-based Thermal Framework | 新世代 Telemetry + Thermal Framework | Linux userspace daemon          |
    | 時代關係 | 傳統方案                         | DPTF 的後繼、加強版                      | 與 DPTF/DTT 無強相依，獨立              |
    | 控制方式 | ACPI + driver                | Telemetry Hub + driver            | Linux thermal subsystem         |
    | 調控能力 | CPU/GPU/風扇/皮膚溫度              | 更細粒度 + AI policy                  | 透過 Linux thermal zone 調控 CPU/風扇 |

## Others
1. **PL1 / PL2 / Tau**  
    Intel RAPL (Running Average Power Limit) 的功耗限制：  
    由 firmware/OS 共同影響, 此為通用電源管理概念, 與下述 MSR/MMIO 實作方式相關
    - PL1 = 長時功耗 (近似 TDP) 
    - PL2 = 短時爆發功 
    - Tau = PL2 持續時間  
2. **MSR vs. MMIO (兩種實作/控制層級)**
    - **MSR (Model Specific Register)**  
        - CPU 內部暫存器，OS 可用 `rdmsr/wrmsr` 操作
        - 傳統 RAPL (PL1/PL2) 常用 MSR
    - **MMIO (Memory-Mapped I/O)**  
        - 由 BIOS / EC / PCH / DPTF / DTT 主導, 透過記憶體映射暫存器控制
        - 來源於 ACPI PPCC 限制
        - **New Gen Intel Platform 常以 MMIO 為主, 優先權高於 MSR, 且可覆蓋 MSR 設定**

## Ubuntu、ChromeOS 與 DPTF/DTT 的實際差異

-   **ChromeOS**  
    Google 與 Intel 做了完整的 **平臺整合**：ESIF (DPTF Core) 、Policy Manager、Participants 皆在體系內；OEM/Google 也確保 BIOS/ACPI tables 齊備、driver 時序正確、策略能落地。  
    **參考**：DPTF 在 ChromeOS/Linux 的整合文件。    [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

-   **Ubuntu (一般 Linux 發行版)**  
    Kernel 有 INT340x 與 thermal framework、userspace 有 thermald，**可以讀到 DPTF 的 ACPI 表**，但 **沒有 ESIF/完整 policy engine**，多半只做基礎降溫；OEM 亦少針對 Ubuntu 做 DPTF policy 校調，所以實際效果與 ChromeOS/Windows 有落差。  
    **參考**：Linux kernel DPTF 文件、thermald 專案。    [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[github.com\]](https://github.com/intel/thermal_daemon)


> **關鍵觀念**：Ubuntu 會「看得到」 firmware 中的 DPTF 策略名稱與表 (如 `optimized‑28h`) ，但多半 **只是讀取/列印**，不會像 ChromeOS/Windows 那樣用 ESIF/Policy Manager 完整落地。

## 總結

*   **Linux Thermal** 是內核原生熱管理；**DPTF** 是 Intel 的平臺級策略 (靠 ACPI/firmware) ，Linux 有驅動可讀取，但 **缺 ESIF**；**DTT** 是 Adaptix 的 runtime 調諧 (主要 Windows/OEM) 。    [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration), [\[dell.com\]](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=853yk)
*   **thermald** 在 Ubuntu 上只做「基礎降溫」，**不是** DPTF 的完整 policy engine。    [\[github.com\]](https://github.com/intel/thermal_daemon)
*   **PL1/PL2/Tau** 決定長短期功耗與爆發；**MSR** 是 CPU 層的設定、**MMIO** 是平臺層設定，**MMIO 常覆蓋 MSR**。
*   你看到的 **`optimized‑28h`** 是 **BIOS/ACPI 裡的 DPTF Passive Policy (PSVT)** 項目，Ubuntu 能「讀到」但未必能完整「執行」；實際是否生效由 **firmware/MMIO** 決定。    [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html)
*   **ChromeOS** 因 Google+Intel 的完整整合 (ESIF/participants/policies/驗證) ，DPTF 充分落地；**Ubuntu** 通常只有讀表＋基礎 cooling，缺少 OEM 的完整 policy 與 ESIF。    [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration)

