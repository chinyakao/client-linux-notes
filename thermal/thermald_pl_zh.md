# Linux Thermald: CPU package power limit (RAPL)
## PL1/PL2 的決定流程（含 MSR vs. MMIO 與 Ubuntu 常見現象）

> 在現代 Intel 平臺上，**最終有效的 PL1/PL2 多半由平臺層（MMIO/firmware/DPTF/DTT）決定**；OS 透過 MSR 設定的數值可能會被覆蓋  

**文字架構圖（由上而下，優先權高 → 低）：**
```
[ Firmware / ACPI ]
    - ACPI DPTF Tables (PSVT/ART/TRT/PPCC/...) 
        → 定義 PL1 Max、降額政策（包含 optimized‑28h）
    - OEM tuning
         ↓ (寫入平臺級參數)
────────────────────────────────────
[Platform Control (MMIO)]
   - SoC/PCH/EC 實際控制有效 PL1/PL2
   - 可覆寫 MSR 設定
         ↓ (真正決定最終 PL1/PL2)
────────────────────────────────────
[OS Kernel (powercap / intel_rapl / cpufreq)]
    - Linux kernel thermal framework（INT340x, i915, cpufreq...）
    - thermald 若修改 MSR PL1 （MSR 設定 RAPL PL1/PL2） → 可能被 MMIO 覆寫
    - powercap/rapl 機制回報最終功耗
                ↓
────────────────────────────────────
[ User Space ]
   - thermald：讀 ACPI → 試著調整 cooling / freq
   - dptfxtract：解碼 ACPI 表（optimized‑28h 被讀到）
```

**常見 Ubuntu 情境：**

*   thermald（或你手動）把 **MSR** PL1 改成 20W
*   **MMIO/firmware 仍維持 PPCC/MAX=40W** 並週期性寫回 → **最終仍 40W**
*   效果：你看到 MSR 短暫變 20W，但功耗/效能曲線依然貼近 40W  
    **參考**：DPTF/ACPI 在 Linux 的資料路徑與 thermald 的角色；OEM 對 DTT/DPTF 的描述。    [\[kernel.org\]](https://www.kernel.org/doc/html/latest/driver-api/thermal/intel_dptf.html), [\[deepwiki.com\]](https://deepwiki.com/intel/dptf/6-platform-integration), [\[dell.com\]](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=853yk)


## Log 中看到的 `optimized‑28h` 規則如何解讀
- **它是 BIOS/ACPI firmware 裡的 DPTF policy 定義（常見屬於 Passive Policy/PSVT 一類）。**
- Linux（含 Ubuntu）透過 **INT340x** 驅動把 **data\_vault** 等 ACPI 二進位表 expose 出來；thermald 或工具（如 dptfxtract）可以 **dump/解碼** 出你看到的條目（如 `optimized‑28h`），**但不代表 Ubuntu 具備完整 DPTF 執行器**  
- 這是 **Passive Policy（PSVT）** 的一段設定：依 **CPU 溫度** 分段下發 **PL1**  
    ```
    $ sudo systemctl stop thermald
    $ sudo thermald --no-daemon --loglevel=debug --adaptive > thermald_log.log
    ```

    Set matched:1 -> This means the condition_set 1 in APCT is matched, as follow:
    ```
    [1769055982][INFO]..apct dump begin..
    [1769055982][INFO]condition_set 1
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem0 comparison:ADAPTIVE_EQUAL argument:0 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0 
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem1 comparison:ADAPTIVE_EQUAL argument:0 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0 
    [1769055982][INFO] target:1 device:\_SB_.IETM condition:Oem2 comparison:ADAPTIVE_EQUAL argument:1 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0 
    [1769055982][INFO] target:1 device:\_SB_.PC00.LPCB.ECDV.TSKN condition:Temperature comparison:ADAPTIVE_LESSER_OR_EQUAL argument:3272 operation:AND time_comparison:0 time:0 stare:0 state_entry_time:0 
    ```
    target:1 -> This means the policy: target_id:1 will be loaded.
    Here, the PL1MAX and PL2PowerLimit are both set as 40W. And, the PSVT table “optimized-28h” will be applied.

    ```
    [1769055982][INFO]..apat dump begin.. 
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.PC00.TCPU domain:9 code:PL1MAX argument:40000
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.PC00.TCPU domain:9 code:PL2PowerLimit argument:40000
    [1769055982][INFO]target_id:1 name:optimized-28H participant:\_SB_.IETM domain:14 code:PSVT argument:optimized-28h
    ```
    Follows is the definition “optimized-28h”. This defines under which condition of the sensor temperature, which PL1 will be set.
    So, under 50℃, the PL1 is as MAX, aka, 40W.

    ```
    [1769055982][INFO]..psvt dump begin..
    [1769055982][INFO]Name :optimized-28h
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:50 domain:9 control_knob:65536 psv.limit:MAX
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:55 domain:9 control_knob:65536 psv.limit:20000
    [1769055982][INFO] source:\_SB_.PC00.TCPU target:\_SB_.PC00.LPCB.ECDV.TMEM priority:2 sample_period:10 temp:65 domain:9 control_knob:65536 psv.limit:20000
    ```

## 實作與驗證：如何在 Ubuntu 上釐清「誰在主導 PL1/PL2」？


> **目標**：分辨 **MSR 設定值** 與 **實際有效值（多半受 MMIO/firmware 主導）** 的差異。

**建議步驟（概述）：**

1.  **讀 ACPI/DPTF 表**  
    使用 thermald/dptfxtract 的 dump/解碼結果比對（找 PSVT、PPCC、ART/TRT）  
    ```
    $ sudo systemctl stop thermald
    $ sudo thermald --no-daemon --loglevel=debug --adaptive > thermald_log.log
    ```
2.  **觀察 MSR 層的 PL1/PL2**
    `rdmsr/wrmsr` 檢視 `MSR_PKG_POWER_LIMIT` 等
    ```
    $ sudo apt install msr-tools
    $ sudo modprobe msr

    # MSR 實際位址：MSR_PKG_POWER_LIMIT = 0x610（Intel 經典）
    $ sudo rdmsr -p 0 0x610

    # 暫存 MSR 0x610 原始值
    $ sudo rdmsr -p 0 0x610 > original_value.txt

    # 修改 0x610 的值
    $ sudo wrmsr -p 0 0x610 <NEW_HEX_VALUE>

    # 觀察 5~30 秒，看是否被改回：
    watch -n 1 "sudo rdmsr -p 0 0x610"
    ```
3.  **觀察 powercap/rapl 實際功耗**
    *  `/sys/class/powercap/intel-rapl:*`
    * `grep . /sys/class/powercap/intel-rapl:0/constraint_*`
    *  壓測下看封包平均功耗是否逼近 40W 還是 20W
4.  **比對 i915/KMS 早期載入與 thermald 日誌**
    *   部分平台 iGPU/telemetry 載入時序會影響 power policy 生效（社群經驗談）  
        **參考**：社群經驗關於 Dynamic Tuning 與 i915/KMS 時序問題。    [\[reddit.com\]](https://www.reddit.com/r/linux/comments/u7zxa0/psa_for_intel_tiger_lake_dynamic_tuning_laptops/)

> **判讀原則**：若 MSR 數值被你改成 20W，但實際功耗在壓測仍向 40W 收斂，且隔段時間 MSR 又被寫回，幾乎可判定 **MMIO/firmware（DPTF/DTT/OEM tuning）在主導**。

