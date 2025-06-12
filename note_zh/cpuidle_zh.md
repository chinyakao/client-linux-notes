# 什麼是 `cpuidle`？

`cpuidle` 是 Linux 核心中的一個 **電源管理子系統**，專門負責在 CPU 閒置 (idle) 時，讓它進入不同的「省電狀態」 (稱為 **C-states**) 

## C-states 是什麼？

當 CPU 沒有工作時，它可以進入不同層級的休眠狀態來節省電力: 

- **C0**: CPU 正在執行指令 (活躍狀態) 
- **C1**: 輕度閒置，快速喚醒
- **C2、C3...Cn**: 越深層的 idle 狀態，省電效果越好，但喚醒時間也越長

`cpuidle` 就是負責根據系統負載與硬體支援，**自動選擇最適合的 C-state**，以達到效能與省電的平衡

## 驅動程式與 `cpuidle` 的關係
Linux 的 cpuidle 框架會根據 CPU 型號載入對應的 idle 驅動：

| CPU 廠商 | Idle 驅動程式 | 備註 |
| --- | --- | --- |
| Intel | intel_idle | Intel 專用, 效能較佳, 支援多種 C-states（C1~C10，依 CPU 型號而異） |
| AMD | amd_idle 或 acpi_idle | 視核心與平台而定, 支援類似的 C-states 管理 |
| ARM | 各平台專屬 | 使用特定平台的 idle 驅動（例如 ARM big.LITTLE 架構, arm_idle, psci_idle 等, 支援 SoC 特定的省電狀態（通常不是叫 C-states，但概念相同）|
| 其他 | 視情況而定 | 需平台支援, 若有對應的 idle 驅動，也可以整合進 cpuidle 框架, 如 RISC-V、PowerPC |

## 如何查看你系統使用哪個 idle 驅動？
你可以在 Linux 終端機輸入以下指令：
```bash
$ cat /sys/devices/system/cpu/cpuidle/current_driver
```

這會顯示目前使用的 idle 驅動，例如：
- intel_idle
- acpi_idle
- psci（ARM 平台）

## 什麼是 Disable `cpuidle`？

停用 CPU 進入深層 idle 狀態的能力，只允許最基本的 idle 模式 (通常是 C1 或完全不進入 C-state) 

這會讓 CPU **保持活躍或淺層 idle 狀態**，不會進入深層省電模式

## 什麼情況下會 Disable `cpuidle`

1. 除錯或測試: 開發者想排除省電機制對效能的影響
2. 低延遲需求的應用: 如音訊處理、即時系統、金融交易系統等即時系統 (Real-Time Systems) 對延遲非常敏感
3. 某些硬體相容性問題: 特定硬體在進入深層 idle 狀態後可能會出現不穩定

4. 伺服器或高效能運算 (HPC): 需要穩定且持續的高效能輸出，不希望 CPU 進入省電狀態

## 使用 Kernel Parameter Disable `cpuidle`

**1. `cpuidle.off=1`**

- 完全停用 CPU Idle 框架，讓系統不再使用任何 C-state。
- 此設定會覆蓋大多數其他 idle 設定，若啟用此參數，則 [2] 與 [3] 將無效。

**2. `processor.max_cstate=1`**

- 限制處理器可進入的最大 C-state
- 設定為 1 時，會停用所有深層 C-state，只允許使用 C0 與 C1

**3. `intel_idle.max_cstate=0`**

- 限制 Intel 專用 idle 驅動可使用的最大 C-state
- 設定為 0 時，會完全停用 Intel Idle 驅動

**4. `idle=poll`**

- 強制 CPU 使用輪詢（polling）迴圈，而非進入任何 C-state。
- 大幅增加功耗，但可確保最高即時反應能力。
- 此設定會完全覆蓋 idle 機制，系統不會進入任何 idle 狀態，只會持續執行輪詢。

**5. `idle=halt`**

- 強制 CPU 使用 HLT 指令進入 idle，避免進入更深層的 C-state。
- 適合進行輕量效能調整。

**使用目的對照表**

| 目的                     | 建議參數       |
|--------------------------|----------------|
| 完全停用 CPU idle        | 1, 4       |
| 僅停用深層 C-states      | 2, 3       |
| 輕量效能調整             | 5           |


### 如何加入 Kernel Parameter to Disable `cpuidle`
```bash
$ sudo nano /etc/default/grub
# 加入以下這行在檔案中
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cpuidle.off=1"
$ sudo update-grub
$ sudo reboot
```

### 如何驗證成功 Disable `cpuidle`
**1. 確認使用的 Kernel Param 有被加入到**
```bash
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-6.11.0-9002-oem root=UUID=... ro quiet splash intel_idle.max_cstate=0  processor.max_cstate=1
```
**2. 確認 `max_cstate` 數值是 `0` or kernel params 的設定值**
```bash
$ sudo cat /sys/module/processor/parameters/max_cstate
```
**3. 確認 `cpuidle` driver 沒有作用 (return nothing or error)**
```bash
$ sudo cat /sys/devices/system/cpu/cpuidle/current_driver
```

