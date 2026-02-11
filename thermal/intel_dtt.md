# Intel DTT (Dynamic Tuning Technology)

> **Intel DTT 是一個跨層系統：  
> Policy 與決策主要在 OS driver（IPF/DTT），  
> BIOS/firmware 提供平台限制與介面，  
> 而真正改變 CPU/SoC 行為的是底層的 platform power-control MMIO / mailbox / MSR。  
> 所以說 DTT 在 BIOS 或在 MMIO，都只描述了其中一個層級。**

## DTT 實際運作的「層級分解」

我們把 DTT 拆成 **5 個層級**來看（由上到下）：

    ┌─────────────────────────────┐
    │ OS / User mode              │
    │  Intel DTT / IPF service    │  ← Policy decision
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Kernel / Driver layer       │
    │  Intel IPF / DTT drivers    │  ← Translation layer
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Firmware runtime (BIOS/UEFI │
    │  + ACPI + SMU/PMC hooks)    │  ← Platform rules
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ SoC / CPU power controller  │
    │  MMIO / mailbox / MSR       │  ← Real enforcement
    └──────────────┬──────────────┘
                   │
    ┌──────────────▼──────────────┐
    │ Hardware (CPU/GPU/VR/EC)    │
    └─────────────────────────────┘

### DTT in BIOS / Firmware

在 BIOS 裡，DTT 主要負責：

*   **在 BIOS 看到的選項, 是否啟用 DTT：**
    > *Intel® Dynamic Tuning Technology: Enabled/Disabled* [\[asus.com\]](https://www.asus.com/support/faq/1053613/)
*   **定義平台能力與限制**
    *   Power budget（PL1/PL2）
    *   Skin temperature model
    *   VR current limits
*   **ACPI / IPF table**
    *   提供 OS driver 可以「合法」調哪些東西

> ⚠️ **但關鍵點是：**  
> **BIOS 不是在 runtime 持續跑 tuning 演算法**

BIOS 做的是：

*   **描述規則**
*   **提供通道**
*   **做安全與上限 clamp**

不是做動態決策。

### DTT in OS / Driver: 動態 tuning

Intel 官方明確定義：

> *Intel DTT is system software drivers configured by OEMs to dynamically optimize performance, thermals, and battery life* [\[station-drivers.com\]](https://www.station-drivers.com/index.php/en/component/remository/Drivers/Intel/Dynamic-Tuning-Technology-%28DTT%29/Intel-Dynamic-Tuning-Technology-%28DTT%29-Version-9.0.11906.54998/lang,en-gb/)

在 Windows 裡你會看到：

*   **Intel Dynamic Tuning Technology**
*   **Intel Innovation Platform Framework (IPF)**

這一層負責：

*   收集 telemetry（溫度、功耗、負載、模式）
*   執行 **policy / AI / heuristic**
*   決定：
    *   PL 要拉高還是壓低
    *   Turbo window
    *   CPU vs GPU power sharing

**這才是「動態 tuning」真正發生的地方**

### DTT in Platform power control MMIO level

當 DTT driver 做出決策後，它**不是直接改 CPU frequency**。

它會透過：

*   **SoC Power Management Controller (PMC)**
*   **Mailbox interface**
*   **MMIO registers**
*   **MSR（部分 legacy path）**

去設定：

*   PL1 / PL2
*   Tau
*   GT / IA power split
*   Current limits

**真正影響硬體行為的，是這一層**

> **DTT 的最終 effect，是透過 platform power-control register 被 enforce**


### 為什麼會有人誤以為「DTT 就在 BIOS」？

幾個實務原因：

1.  **BIOS 不開，OS driver 完全不能動**
    *   沒有 ACPI/IPF capability → driver 啥都不能調
2.  **Embedded Controller / PMC 邏輯部分在 firmware**
    *   有些 thermal / current safety clamp 是 firmware always-on
3.  **OEM 常把 tuning 行為歸類為 BIOS feature**
    *   對外溝通簡化

但從架構來看：

> **BIOS 是 rule + gatekeeper，不是 runtime policy engine**
