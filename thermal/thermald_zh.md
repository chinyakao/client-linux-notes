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
    watch -n1 cat /sys/class/thermal/cooling_device*/cur_stat
    ```
6. 看實際 CPU 行為
    ```
    turbostat
    ```
























































---
# 以下都還沒整理的

# Part A: Thermal Stress Test（驗證 Throttling）

**「溫度越過某個 trip → OS 是否用 *正確方式* throttle」**

## 你要驗證的東西清單（先想好）

對一台 x86 Laptop，你至少要驗證：

| 項目                   | 問題                     |
| -------------------- | ---------------------- |
| trip point 是否真的被觸發   | temp > PSV 時有反應嗎       |
| throttle class       | frequency？power limit？ |
| throttle 強度          | 是否過量                   |
| recovery 行為          | 降溫後會不會解除               |
| jitter / oscillation | 會不會來回震盪                |

***

## 2️⃣ Thermal Stress Test 的「標準觀測面板」

在你開 stress 之前，**請先準備這三個 watch 視窗**：

### (1) Thermal zone + trip

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

👉 你要知道「什麼溫度點開始觸發」

***

### (2) Cooling device 狀態

```bash
watch -n1 '
for c in /sys/class/thermal/cooling_device*; do
  echo "==== $(cat $c/type) ===="
  echo "cur: $(cat $c/cur_state) / max: $(cat $c/max_state)"
done
'
```

👉 **這是 kernel / thermald 真正的動作**

***

### (3) CPU 真實行為（最重要）

```bash
sudo turbostat --interval 1
```

你要盯的是：

*   Avg MHz
*   Package power
*   Throttle flags

❗ **turbostat > cpufreq**

***

## 3️⃣ 設計「可控」的 Stress Pattern（關鍵）

### ✅ 不要一開始就 100% all-core

那樣只會看到：

*   溫度暴衝
*   硬 throttle
*   無法對 trip 精準對齊

***

### ✅ 正確流程（我實際在 Laptop 平台用的）

#### Step 1：Warm up（低斜率）

```bash
stress-ng --cpu 2 --cpu-load 60 --timeout 300s
```

目的：

*   看溫度是否緩慢接近 PSV
*   是否提早 throttle（BIOS bug 常見）

***

#### Step 2：Cross trip（設計性越界）

```bash
stress-ng --cpu 4 --cpu-load 90 --timeout 300s
```

✅ 你要觀察：

*   temp 穿越 PSV 時刻
*   cooling\_device 開始動的時間點
*   CPU power limit 是否下降

***

#### Step 3：Sustain（穩態）

```bash
stress-ng --cpu 4 --cpu-load 90 --timeout 10m
```

✅ 重點不是溫度，而是：

*   是否穩在某一功率 / freq
*   有無 oscillation（上下跳）

***

#### Step 4：Cool-down recovery

```bash
# 停止 stress
```

✅ 檢查：

*   cooling\_device 是否回 0
*   CPU freq / power 是否恢復
*   是否被「卡死在 throttle」

***

## 4️⃣ 你如何判斷「Throttle 是不是正確的？」

### ✅ 正確行為（7 成良好平台）

*   溫度略高於 PSV（±2\~3°C）
*   CPU MHz gradual 降低
*   Package power clamp 明顯
*   無劇烈 oscillation

***

### ❌ 常見錯誤模式（你一定會看過）

#### ❌ Binary throttle（爛）

    4GHz → 400MHz → 4GHz → 400MHz

👉 表示：

*   ACPI trip 設太低
*   thermald policy 不 smooth

***

#### ❌ Over-throttle

*   CPU 卡在低頻
*   溫度其實只有 70°C

👉 90% BIOS \_PSV 問題

***

## 5️⃣ 加碼：Skin temperature 驗證（Laptop 常被忽略）

如果有 skin / acpitz2 這類 zone：

*   CPU zone 不一定是 bottleneck
*   skin zone trip 很可能「先到」

📌 很多 UX 問題其實是 **skin zone throttle**

***

# Part B：DSDT Thermal（給「不想學 ACPI 語言」的人）

## 0️⃣ 你真的不用學 ACPI 語法

### 你要達到的目標只有這個：

> 「我能看出 BIOS 在 thermal 上 *打算讓 OS 做什麼*」

***

## 1️⃣ 把 DSDT 弄出來（必會）

```bash
sudo acpidump > acpi.dump
iasl -d acpi.dump
```

你會得到：

```text
DSDT.dsl
```

***

## 2️⃣ 你在 DSDT 只看這兩種東西

### 🔎 (1) ThermalZone

搜尋：

```bash
grep -n "ThermalZone" DSDT.dsl
```

你會看到類似：

```asl
ThermalZone (TZ00) {
    Method (_TMP, 0) { ... }
    Method (_PSV, 0) { ... }
    Method (_CRT, 0) { ... }
}
```

👉 **這一整段就是 BIOS 對 OS 的 thermal contract**

***

### 🔎 (2) Trip point 本身（最重要）

你會看到像：

```asl
Method (_PSV, 0) {
    Return (0x0C80)
}
```

`0x0C80` = 3200 (tenths of Kelvin)

換算：

    320.0K - 273.15 ≈ 47°C

❗ 如果你看到：

*   \_PSV = 45°C
*   CPU 永遠 throttle

✅ **不是 Linux bug**

***

## 3️⃣ 識別「壞掉的 BIOS Thermal 設計」

### ❌ 症狀 1：Trip 太密

```asl
_PS0 = 45°C
_PS1 = 50°C
_PS2 = 55°C
```

👉 導致震盪

***

### ❌ 症狀 2：ACPI 邏輯依賴 EC state

```asl
If (ECST == 1) {
  Return (LowTemp)
} Else {
  Return (HighTemp)
}
```

👉 EC bug = thermal chaos

***

## 4️⃣ 對照 Kernel / sysfs（關鍵一步）

你要做的是對照：

| DSDT  | sysfs                     |
| ----- | ------------------------- |
| \_PSV | trip\_point\_\*\_passive  |
| \_CRT | trip\_point\_\*\_critical |

✅ 如果 kernel 曝出來的 trip 跟 DSDT 不一致  
→ driver override / quirk

***

## 5️⃣ 你不該做的事（真實經驗）

❌ 一開始就改 DSDT  
❌ 一開始就 blacklist acpi\_thermal  
❌ 一開始就 force thermald xml

✅ 先 **觀察 → 證明 → 再調**

***

# 最重要的工程結論

> **Thermal stress test 是用來「驗證 trip → policy → effect 的鏈條」，不是用來看溫度有多高**

> **DSDT thermal 的價值，不是讓你改 BIOS，而是讓你知道「誰才是兇手」**

***

## 下一步我可以繼續帶你

你可以選一個：
1️⃣ 我帶你「逐行解讀一個真實 Laptop 的 DSDT thermal」
2️⃣ 我幫你設計「自動化 thermal regression test（CI 可用）」
3️⃣ 深挖 thermald policy（XML）如何對抗爛 BIOS

你現在最常遇到的是：

*   throttle 太早？
*   throttle 太重？
*   溫度跳動？
*   還是只有某一個 model 壞？

講一個實際 case，我可以直接用那個情境教你。



可以，而且**非常適合做成「一鍵跑完 + 產出完整 log bundle」**，你就能把不同 BIOS / kernel / thermald 版本的結果拿來做 **逐項比對**（trip 觸發點、cooling device 動作、功耗/頻率、是否震盪、恢復是否正常）。

下面我給你一套我會在 x86 Laptop/Client 上用的 **實戰級 test script（Bash）+ 分析腳本（Python）**，你可以直接複製貼上用。

***

# 0) 你會得到什麼（輸出內容）

每次跑完會生成一個資料夾，例如：

    logs/20260206_132236/
      meta.txt                      # 系統/BIOS/kernel/thermald版本等資訊
      thermal_zones.csv              # 各 thermal_zone temp + trip points（每秒）
      cooling_devices.csv            # 各 cooling_device cur_state/max_state（每秒）
      cpufreq.csv                    # 每個 policy 的 scaling_cur_freq/max/min（每秒）
      turbostat.csv                  # 如果有 turbostat：功耗/MHz/C-state/節流（每秒）
      thermald_journal.log           # thermald 的 journal（可選）
      dmesg_thermal.log              # dmesg 即時抓 thermal/throttle 相關訊息
      steps.log                      # 每個階段開始/結束時間

這樣你要比對時就很簡單：

*   同一台不同 BIOS：比較 `trip` / `cooling` 是否改變
*   同一 BIOS 不同 kernel：比較 sysfs exposure 是否一致
*   不同 thermald config：比較 cooling 行為是否 smooth

***

# 1) 事前準備（建議安裝）

（Debian/Ubuntu 類）

```bash
sudo apt-get install -y stress-ng linux-tools-common linux-tools-generic
```

*   `stress-ng`：產生可控負載
*   `turbostat`：觀測功耗/頻率/節流旗標（最準）
    *   turbostat 有些發行版在 `linux-tools-$(uname -r)` 裡

> 沒有 turbostat 也能跑，只是少一個觀測面板；腳本會自動 fallback。

***

# 2) 一鍵跑：`thermal_stress_test.sh`

把下面存成 `thermal_stress_test.sh`，然後 `chmod +x thermal_stress_test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configurable parameters
# =========================
OUT_ROOT="${OUT_ROOT:-./logs}"
INTERVAL="${INTERVAL:-1}"               # seconds
CPU_WORKERS="${CPU_WORKERS:-4}"

# Stage definitions: (name duration_sec cpu_load)
# You can tune these per platform.
STAGES=(
  "warmup 300 60"
  "cross  300 90"
  "sustain 600 90"
  "cooldown 180 0"
)

CAPTURE_THERMALD_JOURNAL="${CAPTURE_THERMALD_JOURNAL:-1}"  # 1: enable, 0: disable
CAPTURE_DMESG_THERMAL="${CAPTURE_DMESG_THERMAL:-1}"        # 1: enable, 0: disable
CAPTURE_TURBOSTAT="${CAPTURE_TURBOSTAT:-1}"                # 1: enable if available

# =========================
# Helpers
# =========================
ts() { date +"%Y-%m-%d %H:%M:%S"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Safe read function
r() {
  local path="$1"
  if [[ -r "$path" ]]; then cat "$path" 2>/dev/null | tr -d '\n'
  else echo "NA"
  fi
}

# =========================
# Pre-checks
# =========================
need_cmd date
need_cmd awk
need_cmd sed
need_cmd stress-ng

if [[ "$CAPTURE_TURBOSTAT" -eq 1 ]]; then
  if ! command -v turbostat >/dev/null 2>&1; then
    echo "[WARN] turbostat not found; will skip turbostat capture."
    CAPTURE_TURBOSTAT=0
  fi
fi

if [[ "$CAPTURE_DMESG_THERMAL" -eq 1 ]]; then
  need_cmd dmesg
fi

if [[ "$CAPTURE_THERMALD_JOURNAL" -eq 1 ]]; then
  need_cmd journalctl
fi

# Many signals need root for best data (turbostat, dmidecode, journal)
if ! is_root; then
  echo "[WARN] Not running as root. Some captures may be limited."
  echo "       Recommended: sudo $0"
fi

RUN_ID="$(date +"%Y%m%d_%H%M%S")"
OUT_DIR="${OUT_ROOT}/${RUN_ID}"
mkdir -p "$OUT_DIR"

META="$OUT_DIR/meta.txt"
STEPS="$OUT_DIR/steps.log"
TZ_CSV="$OUT_DIR/thermal_zones.csv"
CD_CSV="$OUT_DIR/cooling_devices.csv"
CPUFREQ_CSV="$OUT_DIR/cpufreq.csv"
TURBO_CSV="$OUT_DIR/turbostat.csv"
THERMALD_LOG="$OUT_DIR/thermald_journal.log"
DMESG_LOG="$OUT_DIR/dmesg_thermal.log"

echo "[INFO] Output dir: $OUT_DIR"

# =========================
# Capture meta info
# =========================
{
  echo "run_id=$RUN_ID"
  echo "time=$(ts)"
  echo "uname=$(uname -a)"
  echo "cmdline=$(cat /proc/cmdline 2>/dev/null || true)"
  echo "thermald_status=$(systemctl is-active thermald 2>/dev/null || echo NA)"
  echo "thermald_version=$(thermald --version 2>/dev/null || echo NA)"
  echo "stressng_version=$(stress-ng --version 2>/dev/null | head -n1 || echo NA)"
  echo "turbostat_version=$(turbostat --version 2>/dev/null || echo NA)"
  if command -v dmidecode >/dev/null 2>&1; then
    echo "bios_vendor=$(dmidecode -s bios-vendor 2>/dev/null || echo NA)"
    echo "bios_version=$(dmidecode -s bios-version 2>/dev/null || echo NA)"
    echo "bios_date=$(dmidecode -s bios-release-date 2>/dev/null || echo NA)"
    echo "system_manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null || echo NA)"
    echo "system_product=$(dmidecode -s system-product-name 2>/dev/null || echo NA)"
  else
    echo "dmidecode=NA"
  fi
} | tee "$META" >/dev/null

# =========================
# Discover sysfs entries
# =========================
TZ_DIRS=(/sys/class/thermal/thermal_zone*)
CD_DIRS=(/sys/class/thermal/cooling_device*)

# CPUFreq policies (may not exist on some setups)
CPU_POLICIES=(/sys/devices/system/cpu/cpufreq/policy*)

# Write CSV headers
# thermal_zones.csv: time,zone,type,temp_mC,trip0_type,trip0_temp,...
{
  printf "time"
  for z in "${TZ_DIRS[@]}"; do
    [[ -d "$z" ]] || continue
    zn="$(basename "$z")"
    printf ",%s_type,%s_temp_mC" "$zn" "$zn"
    # include up to 10 trips if present
    for i in $(seq 0 9); do
      [[ -e "$z/trip_point_${i}_type" ]] || continue
      printf ",%s_trip%d_type,%s_trip%d_temp_mC" "$zn" "$i" "$zn" "$i"
    done
  done
  printf "\n"
} > "$TZ_CSV"

# cooling_devices.csv: time,cd,type,cur_state,max_state (wide format)
{
  printf "time"
  for c in "${CD_DIRS[@]}"; do
    [[ -d "$c" ]] || continue
    cn="$(basename "$c")"
    printf ",%s_type,%s_cur,%s_max" "$cn" "$cn" "$cn"
  done
  printf "\n"
} > "$CD_CSV"

# cpufreq.csv: time,policy,cur_khz,min_khz,max_khz,gov
{
  echo "time,policy,cur_khz,min_khz,max_khz,governor"
} > "$CPUFREQ_CSV"

# =========================
# Background monitors
# =========================
MON_PID=""
DMESG_PID=""
JOURNAL_PID=""
TURBO_PID=""

monitor_sysfs() {
  while true; do
    local now
    now="$(ts)"

    # thermal zones row
    {
      printf "%s" "$now"
      for z in "${TZ_DIRS[@]}"; do
        [[ -d "$z" ]] || continue
        printf ",%s,%s" "$(r "$z/type")" "$(r "$z/temp")"
        for i in $(seq 0 9); do
          [[ -e "$z/trip_point_${i}_type" ]] || continue
          printf ",%s,%s" "$(r "$z/trip_point_${i}_type")" "$(r "$z/trip_point_${i}_temp")"
        done
      done
      printf "\n"
    } >> "$TZ_CSV"

    # cooling devices row
    {
      printf "%s" "$now"
      for c in "${CD_DIRS[@]}"; do
        [[ -d "$c" ]] || continue
        printf ",%s,%s,%s" "$(r "$c/type")" "$(r "$c/cur_state")" "$(r "$c/max_state")"
      done
      printf "\n"
    } >> "$CD_CSV"

    # cpufreq (long format; one row per policy)
    for p in "${CPU_POLICIES[@]}"; do
      [[ -d "$p" ]] || continue
      local pn cur mn mx gov
      pn="$(basename "$p")"
      cur="$(r "$p/scaling_cur_freq")"
      mn="$(r "$p/scaling_min_freq")"
      mx="$(r "$p/scaling_max_freq")"
      gov="$(r "$p/scaling_governor")"
      echo "$now,$pn,$cur,$mn,$mx,$gov" >> "$CPUFREQ_CSV"
    done

    sleep "$INTERVAL"
  done
}

start_dmesg_capture() {
  # capture thermal/throttle related kernel messages
  # Use --level if supported? keep it simple.
  dmesg -wT | stdbuf -oL -eL grep -iE "thermal|thrott|PROCHOT|trip|powerclamp|cpu.*temp" \
    > "$DMESG_LOG" &
  DMESG_PID=$!
}

start_thermald_journal_capture() {
  journalctl -u thermald -f --no-pager > "$THERMALD_LOG" &
  JOURNAL_PID=$!
}

start_turbostat_capture() {
  # turbostat CSV output: keep raw for parsing
  # Some systems require modprobe msr
  modprobe msr 2>/dev/null || true
  turbostat --quiet --interval "$INTERVAL" --out "$TURBO_CSV" &
  TURBO_PID=$!
}

cleanup() {
  echo "[INFO] Cleaning up..."
  [[ -n "${MON_PID}" ]] && kill "$MON_PID" 2>/dev/null || true
  [[ -n "${DMESG_PID}" ]] && kill "$DMESG_PID" 2>/dev/null || true
  [[ -n "${JOURNAL_PID}" ]] && kill "$JOURNAL_PID" 2>/dev/null || true
  [[ -n "${TURBO_PID}" ]] && kill "$TURBO_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "[INFO] Starting background monitors..."
monitor_sysfs &
MON_PID=$!

if [[ "$CAPTURE_DMESG_THERMAL" -eq 1 ]]; then
  echo "[INFO] Capturing dmesg thermal..."
  start_dmesg_capture
fi

if [[ "$CAPTURE_THERMALD_JOURNAL" -eq 1 ]]; then
  echo "[INFO] Capturing thermald journal..."
  start_thermald_journal_capture
fi

if [[ "$CAPTURE_TURBOSTAT" -eq 1 ]]; then
  echo "[INFO] Capturing turbostat..."
  start_turbostat_capture
fi

# =========================
# Run stages
# =========================
echo "[INFO] Running stages..."
echo "start $(ts)" | tee -a "$STEPS"

for s in "${STAGES[@]}"; do
  name="$(echo "$s" | awk '{print $1}')"
  dur="$(echo "$s" | awk '{print $2}')"
  load="$(echo "$s" | awk '{print $3}')"

  echo "stage_begin,$name,$(ts),duration=${dur},load=${load}" | tee -a "$STEPS"

  if [[ "$name" == "cooldown" || "$load" -eq 0 ]]; then
    sleep "$dur"
  else
    # Use stress-ng cpu-load to shape load and make it repeatable
    stress-ng --cpu "$CPU_WORKERS" --cpu-load "$load" --timeout "${dur}s" --metrics-brief \
      >> "$OUT_DIR/stressng_${name}.log" 2>&1 || true
  fi

  echo "stage_end,$name,$(ts)" | tee -a "$STEPS"
done

echo "end $(ts)" | tee -a "$STEPS"

echo "[INFO] Done. Logs saved to: $OUT_DIR"
echo "[INFO] Key files: $TZ_CSV $CD_CSV $CPUFREQ_CSV $TURBO_CSV $DMESG_LOG $THERMALD_LOG"
```

***

## 3) 怎麼跑（建議方式）

### 最推薦：root 跑（turbostat / journal / dmidecode 更完整）

```bash
sudo ./thermal_stress_test.sh
```

### 自訂參數（例如：更高負載、更長 sustain）

```bash
sudo OUT_ROOT=./logs INTERVAL=1 CPU_WORKERS=8 ./thermal_stress_test.sh
```

***

# 4) 跑完後你要怎麼「一一比對檢查」？

我給你一個 **檢查清單**（你拿 log 就能逐項對照）

## A. trip 是否如預期觸發？

看 `thermal_zones.csv`：

*   觀察某個 zone 的 `temp_mC` 何時超過 `*_trip*_temp_mC`
*   對照 `steps.log` 的時間點（stage\_begin/cross/sustain）

✅ 正常：cross 時越過 passive trip → cooling 開始上升

***

## B. cooling device 有沒有動、動了多少？

看 `cooling_devices.csv`：

*   `*_cur` 是否從 0 增加
*   是否接近 `*_max`
*   是否在 cooldown 應該回到 0（或顯著下降）

✅ 正常：跨 PSV 後 cur\_state 逐步上升，降溫後逐步下降  
❌ 爛：一直 0（完全沒管到），或瞬間拉到 max（binary throttle）

***

## C. 真的有降到「功耗/頻率」嗎？

看 `turbostat.csv`（若有）：

*   Avg\_MHz 是否下降
*   PkgWatt 是否下降
*   是否出現 throttling/PROCHOT 相關指標（不同版本欄位名不同）

沒 turbostat 就看 `cpufreq.csv`：

*   `scaling_max_freq` 是否被壓低（有些 policy/driver 會做這件事）
*   或 `cur_khz` 是否被壓低

***

## D. 有沒有震盪（oscillation）？

最常見症狀：

*   溫度在 trip 附近上下跳
*   cur\_state 在 0 和 max 來回
*   頻率在高低之間跳

用 CSV 很容易看出「鋸齒狀」。

***

# 5) 加碼：給你一個簡單的分析/對比 Python 腳本（可選）

如果你希望把兩次 run 做「自動比較」，可以用下面這個 `analyze_compare.py`（會輸出幾個關鍵摘要與簡單圖）。

> 你只要把它存成 `analyze_compare.py`，然後 `python3 analyze_compare.py logs/runA logs/runB`

```python
import sys, os
import pandas as pd

def load_run(run_dir):
    tz = pd.read_csv(os.path.join(run_dir, "thermal_zones.csv"))
    cd = pd.read_csv(os.path.join(run_dir, "cooling_devices.csv"))
    cf = pd.read_csv(os.path.join(run_dir, "cpufreq.csv"))
    # parse time as datetime
    for df in (tz, cd, cf):
        df["time"] = pd.to_datetime(df["time"])
    return tz, cd, cf

def summarize(run_dir):
    tz, cd, cf = load_run(run_dir)
    out = []
    # hottest zone (max temp)
    temp_cols = [c for c in tz.columns if c.endswith("_temp_mC") and "trip" not in c]
    hottest = tz[temp_cols].max().sort_values(ascending=False).head(3)
    out.append(("top_temps_mC", hottest.to_dict()))

    # cooling activity
    cur_cols = [c for c in cd.columns if c.endswith("_cur")]
    max_cols = [c for c in cd.columns if c.endswith("_max")]
    peak_cur = cd[cur_cols].max().sort_values(ascending=False).head(10)
    out.append(("peak_cooling_cur", peak_cur.to_dict()))

    # cpufreq behavior: overall min cur_khz during sustain (rough)
    min_cur = cf["cur_khz"].replace("NA", pd.NA).dropna().astype(float).min()
    out.append(("min_cpufreq_cur_khz", float(min_cur) if pd.notna(min_cur) else None))
    return out

def main(a, b=None):
    print(f"=== Summary: {a} ===")
    for k,v in summarize(a):
        print(k, ":", v)
    if b:
        print(f"\n=== Summary: {b} ===")
        for k,v in summarize(b):
            print(k, ":", v)

        # Quick diff hints
        print("\n=== Quick Compare Hints ===")
        a_tz, a_cd, _ = load_run(a)
        b_tz, b_cd, _ = load_run(b)
        a_max = a_tz.filter(like="_temp_mC").filter(regex=r"^(?!.*trip).*$").max().max()
        b_max = b_tz.filter(like="_temp_mC").filter(regex=r"^(?!.*trip).*$").max().max()
        print(f"Max temp (mC): A={a_max} B={b_max}")
        a_peak = a_cd.filter(like="_cur").max().max()
        b_peak = b_cd.filter(like="_cur").max().max()
        print(f"Peak cooling cur_state: A={a_peak} B={b_peak}")

if __name__ == "__main__":
    if len(sys.argv) not in (2,3):
        print("Usage: python3 analyze_compare.py <runA_dir> [runB_dir]")
        sys.exit(1)
    main(*sys.argv[1:])
```

> 之後如果你想要更完整的（自動畫圖、標出跨 trip 的時間點、震盪偵測），我也可以幫你把分析腳本升級到 regression 等級。

***

# 6) 我想確認兩個小資訊，讓腳本更貼近你的平台

1.  你們平台 CPU 是 **Intel 還是 AMD**？（turbostat 欄位/行為會略不同）
2.  你希望 stress 只壓 **CPU**，還是要加上 **GPU / memory / IO**（更像真實 workload）？

如果你回我這兩點，我可以幫你把 script 的 stage/負載模式調成更「像你們的 use case」，例如：

*   Web browsing / Teams 會議型（CPU+GPU burst）
*   編譯/建置型（CPU+mem）
*   長時間 sustained（散熱極限）  
    並且加上 **「自動判定是否 early throttle / over-throttle」** 的規則化檢查輸出。
