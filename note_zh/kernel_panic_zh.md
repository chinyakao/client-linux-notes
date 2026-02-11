# 什麼是 Kernel Panic
「**Kernel panic**」是 Linux 和其他類 Unix 作業系統中一種嚴重錯誤狀態, 表示核心（kernel）遇到無法恢復的錯誤, 導致系統無法繼續正常運作。這通常會導致系統停止運作（freeze）或自動重新啟動。

## 常見導致 kernel panic 的原因包括：

- 驅動程式錯誤或不相容
- 記憶體損壞（RAM 問題）
- 硬體故障（如硬碟、主機板）
- 核心模組（kernel module）錯誤
- 系統呼叫錯誤或非法操作

## 系統開發這測試或核心除錯的方式

- **故意觸發 kernel panic** 的指令: `echo c > /proc/sysrq-trigger`
- `/proc/sysrq-trigger` 是 Linux 的一個特殊介面, 允許透過「Magic SysRq key」功能對核心發出特定命令。
- `echo c` 表示發送 `c` 命令, 這個命令的意思是「觸發一個 crash（kernel panic）」。
> ⚠️ **注意事項**
> - 這個指令會讓系統立即崩潰, 請勿在生產環境或未儲存資料的情況下執行, 請務必在測試環境中使用。
> - 若有設定 kdump, 請先確認 crash kernel 有正確配置。
> - 若在虛擬機中測試, 請確認虛擬機支援 crash dump 或 panic 重啟。


## 什麼情況下會使用這個指令？

### 1. 測試系統在 Kernel Panic 發生時的反應
這是最常見的用途之一。可以用來模擬一個 kernel panic, 然後觀察：
- 系統是否會自動重啟（取決於 /proc/sys/kernel/panic 的設定）
- 是否會產生 crash dump（如果有設定 kdump）
- 是否會觸發硬體 watchdog（用於嵌入式系統或伺服器）

### 2. 驗證 kdump 設定是否正確
kdump 是 Linux 的一個機制, 用來在 kernel panic 發生時儲存記憶體內容（crash dump）, 以便後續分析。可以用這個指令來：
- 測試 crash dump 是否會被正確儲存
- 驗證 dump 的位置與格式
- 確保 kdump kernel 能夠成功啟動

### 3. 除錯與開發用途
在開發驅動程式或核心模組時, 開發者可能需要模擬 panic 狀況來：
- 測試錯誤處理流程
- 驗證系統在極端情況下的穩定性
- 觀察 panic 時的 log 輸出（例如 dmesg）