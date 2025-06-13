# 什麼是 `apport`
Apport 是 Ubuntu 和其他基於 Debian 的發行版（如 Linux Mint、elementary OS）專屬的錯誤回報系統, 它是由 Ubuntu 團隊開發的, 用來自動收集程式崩潰（crash）時的診斷資訊, 並產生一份稱為 Apport report 的錯誤報告。這份報告可以幫助開發者或系統管理員了解錯誤發生的原因

- Apport 是 Ubuntu 專有的工具
- 預設安裝在 Ubuntu 系統中
- 與 Ubuntu 的 bug 回報平台（Launchpad）整合
- `.crash` 檔案格式與報告流程是為 Ubuntu 設計的

## 主要功能
**1. 自動偵測崩潰**

當應用程式或系統元件崩潰時, apport 會自動啟動並收集相關資訊。

**2. 產生錯誤報告 (crash report)**

這份報告通常儲存在 /var/crash/ 目錄下, 副檔名為 .crash。內容包括：
- 程式名稱與版本
- 錯誤訊息與堆疊追蹤（stack trace）
- 執行環境（kernel、glibc、Python 等版本）
- 使用者與系統資訊（如 CPU 架構、記憶體狀態）

**3. 與 Launchpad 整合 (Ubuntu 的 bug 回報平台)**

使用者可以選擇將錯誤報告上傳到 Launchpad, 供開發者分析。

## 使用方式
Apport 預設是自動運作的, 當以下情況發生時, Apport 會自動啟動並產生 `.crash` 檔案：

- 程式崩潰（Segmentation fault、core dump 等）
- Python 程式未處理的例外
- 系統服務失敗（如 systemd 單元崩潰）
- 內核錯誤（需額外設定）
這些報告會被儲存在 `/var/crash/` 目錄中。

### 檔案位置
```bash
ls /var/crash/
```
可能會看到像這樣的檔案
```
_usr_bin_gnome-shell.1000.crash
_usr_bin_python3.1000.upload
_usr_bin_python3.1000.uploaded
```
### 查看 Apport 報告內容
可以使用 apport-unpack 指令來解壓 .crash 檔案
會將報告內容解壓成多個可讀的文字檔案, 例如 Stacktrace.txt、ProcStatus.txt、CoreDump.gz 等
```bash
mkdir crash_report
apport-unpack /var/crash/_usr_bin_python3.1000.crash crash_report/
```
會產出以下檔案:
| 檔案名稱 | 說明 |
| --- | --- |
| Stacktrace.txt | 錯誤發生時的堆疊追蹤 |
| ProcStatus.txt | 程式的記憶體與執行狀態 |
| CoreDump.gz | 若有產生 core dump, 會壓縮在這裡 |
| ExecutablePath | 崩潰的執行檔路徑 |
| Signal | 崩潰的訊號（如 SIGSEGV） |
| ProblemType | 問題類型（如 Crash、Bug） |
| Package | 所屬的套件名稱與版本 |

若需要進階分析, 可以分析 CoreDump.gz, 可以解壓縮並用 gdb 分析：
這需要你知道是哪個執行檔造成錯誤（可從 ExecutablePath 找到）。
```
gunzip CoreDump.gz
gdb /path/to/executable CoreDump
```

### 手動上傳 Apport Report
可以使用 `apport-bug` 或 `apport-cli` 來手動回報錯誤, 例如：
```bash
apport-bug /path/to/crash/file
```

或針對特定套件：
```bash
apport-bug firefox
```
會開啟 GUI 或 CLI 介面, 讓你檢查報告並選擇是否上傳。

### 關閉 Apport (不會自動產生 report)
**1. 編輯設定檔 `/etc/default/apport`** 將 `enabled=1` 改為 `enabled=0`

**2. Disable Service**

```bash
sudo systemctl disable apport.service
sudo systemctl stop apport.service
```
## 延伸 Core Dump

> [! NOTE]
> 
> - Apport 使用自己的 core dump 機制, 並不完全依賴 ulimit -c 來決定是否產生 core dump
> - 當 core dump 被導向 Apport（透過 core_pattern 設定）, Apport 會主動從記憶體中擷取核心資訊, 並壓縮成 CoreDump.gz, 即使 ulimit -c 是 0
> - 這是 Ubuntu 的預設行為, 目的是讓開發者能夠在使用者不需額外設定的情況下, 仍然取得完整的錯誤診斷資訊。
> - 檢查 `cat /proc/sys/kernel/core_pattern`, 若輸出是 `|/usr/share/apport/apport %p %s %c %P` 代表 core dump 被送到 Apport 處理, 而不是寫入磁碟。這種情況下, ulimit -c 的設定就不會阻止 Apport 擷取記憶體內容。

Core dump（又稱 core file 或 memory dump）是當程式發生嚴重錯誤（例如 segmentation fault）時, 系統將該程式當下的記憶體內容、暫存器狀態、堆疊資訊等儲存下來的檔案。

這個檔案可以讓開發者或系統管理員事後使用除錯工具（如 gdb）來還原當時的執行狀態, 找出錯誤原因。
包含了以下資訊: 
1. 程式的記憶體映像（memory image）
2. CPU 暫存器狀態
3. 堆疊追蹤（stack trace）
4. 程式計數器（Program Counter）
5. 錯誤訊號（如 SIGSEGV）
6. 執行緒資訊（threads）

### 檢查 Core Dump 設定

如果輸出是 `0`, 代表 core dump (核心轉儲) 功能被禁用, 這會導致 Apport 或其他工具無法收集程式崩潰時的記憶體狀態
```bash
ulimit -c
```

### 臨時啟用（只對當前 shell 有效）

```bash
ulimit -c unlimited
```

這會允許產生不限大小的 core dump, 但只對目前的終端機 session 有效。可以用這個方式測試 core dump 是否會產生。

### 永久啟用（建議）

要讓 core dump 在每次開機後都啟用, 需要修改幾個設定檔：

**1. 修改 `/etc/security/limits.conf`**

```bash
sudo nano /etc/security/limits.conf

# 在檔案底部加上這兩行（針對所有使用者）：
* soft core unlimited
* hard core unlimited
```

**2. 修改 PAM 設定**

確保 PAM 模組會載入 limits 設定：

```bash
sudo nano /etc/pam.d/common-session

# 確認有這一行（如果沒有就加上）：
session required pam_limits.so
```

**3. 最後：重新登入或重開機**

### 如何產生 Core Dump？

1. **允許 core dump：**

```bash
ulimit -c unlimited
```

2. **執行會崩潰的程式**（如 segmentation fault）

3. **檢查 core dump 是否產生：**

```bash
ls core*
```

或使用：

```bash
coredumpctl list
```

### 如何分析 Core Dump？

使用 `gdb`：

```bash
gdb /path/to/executable core
```

進入後可以使用指令：

- `bt`：顯示 backtrace（堆疊追蹤）
- `info locals`：查看區域變數
- `list`：顯示原始碼
- `frame`：切換堆疊框架

### 儲存位置與命名規則

由 `kernel.core_pattern` 控制：

```bash
cat /proc/sys/kernel/core_pattern
```

範例：

- `core`：儲存在當前目錄
- `/var/crash/core.%e.%p.%t`：包含程式名、PID、時間戳

**設定 core dump 儲存位置（可選）**

可以設定 core dump 儲存的檔名與路徑：

```bash
sudo sysctl -w kernel.core_pattern=/var/crash/core.%e.%p.%t
```

若要永久生效, 請加到 `/etc/sysctl.conf`：

```
kernel.core_pattern=/var/crash/core.%e.%p.%t
```

> [! NOTE]
> 
> - Core dump 可能包含敏感資訊（如密碼、金鑰）, 不應隨意分享。
> - 在生產環境中通常會關閉或限制 core dump。
> - 可搭配 `systemd-coredump` 或 `Apport` 自動收集與管理。
