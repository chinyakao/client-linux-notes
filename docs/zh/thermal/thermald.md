---
title: "thermald"
parent: "散熱"
grand_parent: "中文"
nav_order: 1
lang: zh
---

## 整體 Thermal Control 架構

    [ Silicon / Sensors ]
            ↓
    [ EC / PMIC / On-die thermal sensor ]
            ↓
    [ ACPI / Firmware (BIOS / UEFI) ]
        BIOS 用 ACPI「描述」 thermal 世界
            ↓
    [ Linux Kernel thermal framework ]
        把 ACPI 翻成 sysfs
            ↓
    [ Userspace: thermald / power daemon ]
        看 sysfs，做 policy
            ↓
    [ Cooling devices: freq / power / fan ]

## HW Level: Thermal 是怎麼量的？

### 1. Thermal Sensor 類型

常見來源: 

*   **CPU on-die sensor (DTS)**
    *   Intel: Digital Thermal Sensor
    *   AMD: Tctl / Tdie
*   **SoC sensors**
*   **Board sensor**
    *   via EC, I2C, SMBus
*   **GPU thermal**
*   **VR / PMIC / Battery sensor**

最終會被 BIOS 或 Kernel 匯出成 ACPI 或 hwmon / thermal\_zone。

### 2. 硬體會做的事情 (不等 OS) 

**Thermal hardware trip (不可避免)**

*   PROCHOT#
*   THERMTRIP#
*   SoC internal hard limit

⚠️ 這些是 **最後防線**

*   OS 完全來不及干預
*   溫度過高直接降頻或關機

## BIOS / Firmware (ACPI) 層

### ACPI Thermal Zone
一個 thermal zone = 一個溫度邏輯單位  
例如: 
* CPU package
* Skin temperature
* VR / motherboard

BIOS 會透過 ACPI 定義 thermal policy, 定義類似這樣的概念: 
```
Thermal Zone: CPUZ
  - current temperature
  - trip points (如下解釋)
  - cooling devices
```
### ACPI Trip Point

*   `_TZ`: thermal zone
*   `_TMP`: 目前溫度
*   `_CRT`: Critical trip (直接關機, 由 BIOS/HW 處理) 
*   `_PSV`: Passive trip (降頻, OS throttle 處理) 
*   `_HOT`: Sleep 用 (ACPI 處理?)
*   `_ACx`: Active trip (風扇, BIOS or OS 處理) 

### ACPI Passive Cooling vs Active Cooling
**Passive cooling (被動節流, thermald 主要處理的)**
- 降 CPU freq
- 限 package power
- 不動風扇
- 舊系統靠 BIOS；新系統交給 OS (thermald)
- ACPI 不會直接 throttle CPU
    - ACPI 只會說:  
    「當溫度 > 80°C，請 OS 開始想辦法」  
    「怎麼做」是 OS / thermald 的事

**Active cooling (thermald 常常管不到)**
- 風扇
- 幾乎都被 BIOS / EC 綁死

### BIOS 與 OS 的責任切分

| 模式                           | Control                      |
| ----------------------------- | ---------------------------- |
| Legacy                        | BIOS control fans / throttle |
| Modern (Intel recommendation) | OS control via thermald      |
| Broken BIOS                   | 什麼都做 (Debug nightmare)    |

**thermald 偏好:**

*   BIOS 提供 **sensor + cooling device**
*   Policy 交給 OS

## Linux Kernel Thermal Framework

Kernel 提供「管道」，不做政策 (policy 在 userspace)   
Kernel 把 ACPI 轉成：
```
thermal zone
trip point
cooling device
```
全部放在:
```
/sys/class/thermal/
```
### Kernel 介面位置

```bash
/sys/class/thermal/
├── thermal_zone0/
│   ├── temp
│   ├── trip_point_0_temp
│   ├── trip_point_0_type
├── cooling_device0/
│   ├── type
│   ├── cur_state
│   ├── max_state
```

**1. Thermal Zone**
```
ls /sys/class/thermal/thermal_zone*
```
溫度來源, 常見: 
- acpitz (ACPI thermal zone)
- x86_pkg_temp (CPU package sensor) 

```
$ cat /sys/class/thermal/thermal_zone0/type
x86_pkg_temp
$ cat /sys/class/thermal/thermal_zone0/temp
57000
```
表示溫度來源於 CPU package sensor, 目前 57°C (溫度單位: **millidegree Celsius**)

**2. Trip Point**

溫度門檻 (passive / active / critical) 
```
$ cat /sys/class/thermal/thermal_zone0/trip_point_0_type
passive
$ cat /sys/class/thermal/thermal_zone0/trip_point_0_temp
80000
```
表示溫度 80°C 開始 throttle

**3. Cooling Device**
OS 能用來降低溫度的東西: 
```
cat /sys/class/thermal/cooling_device*/type
```
常見:  
- Processor
- intel_powerclamp (CPU power clamp (Intel RAPL))
- Fan (通常沒用)

*   CPU freq?
*   GPU freq?

## thermald 是什麼、負責什麼？

### thermald 定位

*   Intel 發起 (但非 Intel-only) 
*   **Userspace Thermal Policy Daemon**
*   根據: 
    *   ACPI info
    *   kernel thermal
    *   CPU features (RAPL / P-state)

負責 **何時用什麼 cooling device**

### thermald 能做的事情

*   **CPU frequency limit**
*   **CPU package power limit (RAPL)**
*   CPU core hot-plug (較少) 
*   Fan control (若 BIOS 放權) 
*   Multiple zone coordination

### thermald 的資料來源

```text
/sys/class/thermal/*
/sys/class/hwmon (sysfs hwmon)
ACPI tables
MSR (RAPL / pkg power)
```

## 如何「看」當下 Thermal 狀態 (最重要) 

### 看 thermal zones

```bash
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp
```

### 一次看清楚

```bash
watch -n1 'paste \
  /sys/class/thermal/thermal_zone*/type \
  /sys/class/thermal/thermal_zone*/temp'
```

### 看 cooling device

```bash
cat /sys/class/thermal/cooling_device*/type
cat /sys/class/thermal/cooling_device*/cur_state
```

常見 type: 

*   `Fan`
*   `Processor`
*   `intel_powerclamp`

### CPU throttling 狀態

```bash
cat /proc/cpuinfo | grep MHz
```
or
```bash
turbostat
```

## thermald Debug 全流程

1. 確認 thermald 在跑
    ```bash
    systemctl status thermald
    ```
2. 前景 Debug 模式
    ```bash
    thermald --no-daemon --loglevel=debug
    ```

    會看到: 
    *   zone register
    *   trip trigger
    *   cooling decision

    要看的是:   
    - 哪個 thermal zone 被觸發
    - 用了哪個 cooling device
    - 限了多少 power / freq

3. 常見 Debug 情境
    - 情境 A: 溫度高但沒降頻  
    檢查
        * 有沒有 passive trip
        * 是否 trip point 設得太高
        * cooling device 是否存在
        * thermald 是否有權操作 cooling device

        ```bash
        $ cat trip_point*_type
        $ cat cooling_device*/type
        $ cat cooling_device*/max_state
        ```
    - 情境 B: 一開機就被 throttle (一跑負載就卡 400MHz)  
    常見原因: 
        * BIOS `_PSV` 非常低
        * EC 回報錯誤溫度
        ```bash
        dmesg | grep thermal
        ```
    - 情境 C: 風扇完全不動
        *   BIOS 沒開放 fan control
        *   EC 綁死  
        => thermald **無法救**

**不要一開始就改 thermald config, Debug 順序一定要是:** 

1.  HW sensor 正不正常 (確認感測器合理)
    ```
    watch -n1 cat /sys/class/thermal/thermal_zone*/temp
    ```
2.  BIOS ACPI table 是否合理
3.  Kernel thermal 是否註冊成功
4.  thermald 是否有 policy (確認 trip point)
    ```
    grep . /sys/class/thermal/thermal_zone*/trip*
    ```
5.  cooling device 是否真的影響功耗 / freq (確認 cooling device 有效)
    ```
    watch -n1 cat /sys/class/thermal/cooling_device*/cur_state
    ```
6. 看實際 CPU 行為
    ```
    turbostat
    ```

## 散熱壓力測試：驗證 throttle 是否正確

目的不是看溫度有多高，而是驗證「溫度越過 trip → policy → cooling 生效」這條鏈是否正確。

### 要驗證的項目

| 項目 | 問題 |
| --- | --- |
| trip point 是否真的被觸發 | 溫度超過 `_PSV` 時有反應嗎 |
| throttle 方式 | 降頻？限功耗？ |
| throttle 強度 | 是否過量 |
| 恢復行為 | 降溫後會不會解除 |
| 震盪 | 會不會在高低之間來回跳 |

### 觀測面板（開始加壓前先準備好）

1. Thermal zone 與 trip point：
    ```bash
    watch -n1 '
    for z in /sys/class/thermal/thermal_zone*; do
      echo "==== $(cat $z/type) ===="
      echo "temp: $(cat $z/temp)"
      grep . $z/trip_point*_type 2>/dev/null
      grep . $z/trip_point*_temp 2>/dev/null
    done
    '
    ```
2. Cooling device 狀態（kernel / thermald 真正做的動作）：
    ```bash
    watch -n1 '
    for c in /sys/class/thermal/cooling_device*; do
      echo "==== $(cat $c/type) ===="
      echo "cur: $(cat $c/cur_state) / max: $(cat $c/max_state)"
    done
    '
    ```
3. CPU 實際行為（最重要，turbostat 比 cpufreq 準）：
    ```bash
    sudo turbostat --interval 1
    ```
    看 Avg MHz、Package power、throttle 旗標。

### 可控的加壓流程

不要一開始就 100% 全核心加壓，那樣只會看到溫度暴衝和硬 throttle，無法對準 trip point。

1. **Warm up（緩慢升溫）**：`stress-ng --cpu 2 --cpu-load 60 --timeout 300s`  
    看溫度是否慢慢接近 `_PSV`，以及是否提早 throttle。
2. **Cross trip（刻意越過 trip）**：`stress-ng --cpu 4 --cpu-load 90 --timeout 300s`  
    觀察溫度穿越 `_PSV` 的時間點、cooling device 開始動作的時間點、CPU 功耗上限是否下降。
3. **Sustain（穩態）**：`stress-ng --cpu 4 --cpu-load 90 --timeout 10m`  
    重點是是否穩定在某個功率 / 頻率，有沒有震盪。
4. **Cool down（恢復）**：停止加壓，確認 cooling device 回到 0、CPU 頻率與功耗恢復，沒有卡在 throttle 狀態。

這個流程已寫成腳本並會記錄所有數據，見[散熱壓力測試](stress-test.md)。

### 判斷 throttle 是否正確

- **正常**：溫度略高於 `_PSV`（約 2~3°C）、CPU 頻率逐步下降、package power 明顯被限制、沒有劇烈震盪。
- **Binary throttle**：`4GHz → 400MHz → 4GHz → 400MHz` 來回跳，通常是 trip 設太低或 policy 不平滑。
- **Over-throttle**：CPU 卡在低頻，但溫度其實只有 70°C 左右，優先檢查 BIOS 的 `_PSV`。
- **Skin temperature**：筆電如果有 skin 類的 thermal zone（例如 `acpitz` 的其他 zone），它的 trip 可能比 CPU zone 先到，很多使用體驗問題其實是 skin zone 在 throttle。

## 讀 DSDT 裡的 thermal 設定（不用學 ACPI 語法）

目標只有一個：看出 BIOS 打算讓 OS 在散熱上做什麼。

1. 取出並反組譯 ACPI 表：
    ```bash
    sudo acpidump > acpi.dump
    acpixtract -a acpi.dump
    iasl -d dsdt.dat
    ```
2. 找 thermal zone：`grep -n "ThermalZone" dsdt.dsl`，會看到類似
    ```asl
    ThermalZone (TZ00) {
        Method (_TMP, 0) { ... }
        Method (_PSV, 0) { ... }
        Method (_CRT, 0) { ... }
    }
    ```
    這一段就是 BIOS 和 OS 之間的散熱約定。
3. 看 trip point 的值。ACPI 溫度單位是 0.1 K：
    ```asl
    Method (_PSV, 0) { Return (0x0C80) }
    ```
    `0x0C80` = 3200 → 320.0 K − 273.15 ≈ 47°C。如果 `_PSV` 這麼低，CPU 一直被 throttle 就**不是 Linux 的 bug**。
4. 常見的 BIOS 問題：
    - 多個 trip point 設得太近，容易震盪。
    - trip 的回傳值依賴 EC 狀態（例如 `If (ECST == 1) { Return (LowTemp) }`），EC 出錯時散熱行為就會亂掉。
5. 和 sysfs 對照：`_PSV` 對應 `trip_point_*_type` 為 `passive` 的 trip，`_CRT` 對應 `critical`。如果 kernel 顯示的 trip 和 DSDT 不一致，代表有 driver override 或 quirk。

### 不要一開始就做的事

- 改 DSDT
- blacklist `acpi_thermal`
- 強制套用 thermald 的 XML 設定

先觀察、證明，再調整。DSDT 的價值不是讓你改 BIOS，而是讓你知道問題出在誰身上。
