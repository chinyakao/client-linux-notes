# What is Linux s2idle?
s2idle 是 Linux 在 ACPI 電源管理架構下的一種睡眠模式，全名 Suspend-to-Idle。它是 Linux 對應 Modern Standby (S0ix) 的實作，屬於 ACPI S0 工作狀態的延伸，而非傳統的 S3 (Suspend-to-RAM)。
在 s2idle 模式下：
  - 系統看似休眠，但仍保持在 S0 電源狀態。
  - CPU 和記憶體仍有部分供電，裝置可以選擇進入低功耗。
  - 支援快速喚醒，類似手機的待機。

## Modern Standby (S0ix) (= Linux s2idle) 
- 定義：Modern Standby 是 Windows 平台上的一種低功耗待機模式，屬於 S0 (工作狀態) 的延伸，讓系統在待機時仍能保持網路連線、背景同步，類似手機的「待機」。
- 特點：
  - 系統看起來休眠，但 CPU、記憶體仍有部分供電。
  - 支援快速喚醒。
  - 主要在 Windows 10/11 上使用，硬體必須符合 ACPI S0ix 規範。
  - Linux 也開始支援 S0ix，但需要硬體與核心支援（Kernel 5.x 以上），並且要在 BIOS 啟用「Modern Standby」。
  - **在 Linux 對應 S0ix 的模式叫做 `s2idle`**

## S3 (Suspend to RAM)
- 定義：S3 是傳統的 ACPI 睡眠狀態，俗稱「睡眠模式」。
- 特點：
    - Linux 長期有支援 S3
    - CPU、裝置完全斷電，只保留 RAM 供電。
    - 喚醒速度比休眠快，但比 Modern Standby 慢。
    - 廣泛支援於 Linux、Windows 與舊硬體。

## Command
### `$ systemctl suspend`
- `systemctl suspend` 所對應的睡眠模式取決於系統的 `/sys/power/mem_sleep` 設定：
    - 如果硬體與核心支援 S3 (Suspend-to-RAM)，則會進入 S3。
    - 如果硬體只支援 Modern Standby (S0ix)，則會進入 `s2idle`（Linux 對應 S0ix 的模式）。
- 可以用以下指令檢查：
    ```
    cat /sys/power/mem_sleep
    ```
- 輸出可能是：
    - `s2idle [deep]` → deep 對應 S3，s2idle 對應 S0ix。
    - `[s2idle] deep` → 系統預設使用 s2idle（Modern Standby）。
    - 若只顯示 `[s2idle]`，沒有其他選項 (如 `deep`)，表示硬體或 BIOS 不支援 S3 (Suspend-to-RAM)，只有 Linux 的 s2idle 模式可用。

### `$ rtcwake -m mem`
在 Linux 中，`-m mem` 會呼叫 Suspend-to-RAM，但實際模式由 `/sys/power/mem_sleep` 決定
`rtcwake -m mem` 不保證一定是 S3，它只是執行 `systemctl suspend` 的底層機制。

### `$ cat /sys/power/suspend_stats/total_hw_sleep`
- `total_hw_sleep` 是 Linux 的 硬體進入低功耗狀態的累積時間（通常來自 `/sys/kernel/debug/pmc_core/slp_s0_residency_usec` 或類似的硬體計數器），用來判斷系統是否真的進入硬體層級的睡眠。
- S3 (deep)：
    - 系統進入 ACPI S3，CPU、裝置斷電，只保留 RAM。
    - 硬體會進入深度睡眠，total_hw_sleep 幾乎一定會增加（因為平台進入低功耗狀態）。
- s2idle (Modern Standby)：
    - 系統仍在 S0ix，CPU有部分供電，裝置可能保持活動。
    - 是否增加取決於硬體是否支援 S0ix 並正確進入低功耗狀態。
    - 如果硬體或 BIOS 沒有正確配置，total_hw_sleep 可能 不增加或增加很少。

## Linux Tool or Settings
- [stress_s2idle.sh](https://github.com/chinyakao/linux_tool_script/blob/main/stress_s2idle.sh)
- Intel: https://github.com/intel/S0ixSelftestTool
- AMD: https://github.com/superm1/amd-debug-tools/blob/master/docs/amd-s2idle.md

-  Ubuntu GNOME
    - 在 Ubuntu 的桌面環境（例如 GNOME），當使用 UI 選擇 Suspend 時，實際上會進入 `systemctl suspend` 所對應的睡眠模式。
    - Ubuntu UI 的 Suspend 不是固定 S3 或 S0ix，而是依硬體與核心支援決定，預設會選擇第一個可用模式（通常是 s2idle 在新硬體上）。

- Checkbox (Ubuntu Test Tool)
    - Ubuntu 所使用的 [Checkbox (Test Tool)](https://github.com/canonical/checkbox) 中的 "Suspend (S3) stress test" 其實不一定只測 S3（Suspend-to-RAM），而是會呼叫 `systemctl suspend` 根據底層支援自動選擇模式
    - 測試啟動時預設是 S3，實際執行時**視系統設定**轉去 `s2idle`。
    - 如果硬體與內核不支援 S3，只會跑 s2idle。
    - 若硬體支援 S3，而且 `/sys/power/mem_sleep` 預設有 `deep` 選項，需先手動切換系統強制使用 S3，再執行 Checkbox 測試。
