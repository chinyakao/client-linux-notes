---
title: "Intel iGPU 掉到 30 FPS"
parent: "顯示與平台"
grand_parent: "中文"
nav_order: 1
lang: zh
---

# Intel iGPU：全螢幕掉到 30 FPS
## 先確認顯示 driver 有載入，再找出是誰讓 FPS 減半

## 症狀

- 筆電上的 Intel 內顯
- 顯示系統：Xorg / X Window
- 全螢幕時更新率 / FPS 從 60 掉到 30，畫面卡頓

## 0. 先講結論

- 60 → 30 FPS 通常**不是** GPU 效能不夠，而是某個省電或同步機制讓畫面「半速」運作。
- 最常見的原因：
  - PSR（Panel Self Refresh）
  - DRRS（Dynamic Refresh Rate Switching）
  - GuC / HuC firmware 沒載入
  - Xorg 全螢幕 + compositor 的路徑
- 排查順序：driver 有沒有綁上 → 是不是硬體繪圖 → 哪個省電功能讓更新率減半。

## 1. iGPU 有沒有綁上 kernel driver？

較新的 Intel GPU 會依平台和 kernel 版本使用 `i915` 或較新的 `xe` driver。步驟都一樣，換成你看到的模組名稱即可。

### 1.1 找出裝置和 PCI ID

```bash
lspci -nn | grep -E "VGA|Display"
```

記下 `[8086:xxxx]` 這個 ID。新平台可能會出現多個 function，只看到一個也正常。

### 1.2 目前用的是哪個 driver

```bash
lspci -nnk | grep -A3 -E "VGA|Display"
```

判讀方式：

*   `Kernel driver in use: i915`（或 `xe`）→ driver 已經綁上
*   只有 `Kernel modules:`，沒有 `driver in use` → probe 失敗、裝置需要 `force_probe`，或模組被 blacklist
*   完全沒有 driver → kernel 太舊不認得這顆 GPU，或缺少模組

### 1.3 模組有沒有載入

```bash
lsmod | grep -E "^(i915|xe)"
sudo modprobe i915   # 手動載入測試
```

### 1.4 看 dmesg 的 probe 結果

```bash
dmesg | grep -i -E "i915|xe "
```

注意這些關鍵字：

*   `Device is not supported` / `force_probe` → kernel 認得這個 ID，但預設沒有啟用
*   `Failed to load ... firmware`（DMC / GuC / HuC）→ 更新 `linux-firmware`

## 2. 是不是退回軟體繪圖（llvmpipe）？

```bash
glxinfo | grep -E "OpenGL renderer|OpenGL version"
ls -l /dev/dri
```

*   Mesa Intel renderer → 硬體繪圖
*   `llvmpipe` → CPU 軟體繪圖，回到第 1 步檢查
*   `/dev/dri` 底下應該有 `card0` 和 `renderD128`

> 穩定卡在 30 FPS 通常不是 llvmpipe（那會又慢又不穩），而是同步或省電機制。

## 3. 為什麼剛好是 30 FPS？

**30 FPS 是一個訊號，不是巧合。**代表更新率 / vblank 被減半（60 → 30），而不是繪圖跟不上。

常見原因：

*   PSR（Panel Self Refresh）
*   DRRS（在 60 / 48 / 30 Hz 之間切換）
*   Display DC states / clock gating
*   Xorg Present / page flip / compositor 把畫面誤判成靜態

## 4. 頭號嫌疑：PSR

### 4.1 查看 PSR 狀態

```bash
sudo mount -t debugfs none /sys/kernel/debug
sudo cat /sys/kernel/debug/dri/0/i915_edp_psr_status
```

如果顯示 `PSR enabled` / `PSR2 enabled`，PSR 嫌疑很大。

### 4.2 關掉 PSR 驗證

在 kernel cmdline 加上：

    i915.enable_psr=0

GRUB 範例：

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"
sudo update-grub
sudo reboot
```

全螢幕回到 60 FPS → 確認是 PSR。

## 5. 第二嫌疑：DRRS

DRRS 會讓面板在 60、48、30 Hz 之間切換。關掉比較看看：

    i915.enable_drrs=0

> PSR 和 DRRS 常常一起出現。

## 6. GuC / HuC firmware

```bash
dmesg | grep -i -E "guc|huc|dmc"
```

正常應該看到 `GuC firmware ... loaded`、`HuC firmware authenticated`。載入失敗的話先更新 `linux-firmware`。

測試時可以強制開啟 GuC/HuC：

    i915.enable_guc=3

## 7. Xorg / Compositor

### 7.1 Session 類型

```bash
echo $XDG_SESSION_TYPE
```

*   `x11` → 比較容易遇到這個問題
*   `wayland` → 更新率管理通常比較穩定

### 7.2 Compositor

```bash
picom --no-vsync
```

或直接關掉 compositor 比較。

### 7.3 Xorg driver

新平台請用 `modesetting`，不要用舊的 `intel` DDX：

```bash
grep -i "driver" /var/log/Xorg.0.log | head
```

## 8. 排除 GPU 效能不足

```bash
sudo cat /sys/kernel/debug/dri/0/i915_frequency_info
sudo apt install intel-gpu-tools
sudo intel_gpu_top
```

如果 GPU 使用率不高、時脈也一直很低，FPS 卻固定在 30，就是電源或顯示的問題，不是效能。

## 9. A/B 測試

```text
i915.enable_psr=0
i915.enable_drrs=0
i915.enable_guc=3
```

**一次只改一個參數**並記錄結果，才知道是哪一個解決了問題。

## 10. 長期解法

改用 Wayland session，大多數情況下 60 → 30 FPS 的問題就會消失。

## 11. 快速排查清單

```bash
uname -r
lspci -nnk | grep -A3 -E "VGA|Display"
lsmod | grep -E "^(i915|xe)"
dmesg | grep -i -E "i915|guc|huc|dmc|psr|drrs"
glxinfo | grep -E "OpenGL renderer|OpenGL version"
sudo cat /sys/kernel/debug/dri/0/i915_edp_psr_status
sudo cat /sys/kernel/debug/dri/0/i915_frequency_info
sudo intel_gpu_top
echo $XDG_SESSION_TYPE
```

## 12. Kernel cmdline 速查

*   關 PSR：`i915.enable_psr=0`
*   關 DRRS：`i915.enable_drrs=0`
*   開 GuC/HuC：`i915.enable_guc=3`
*   強制 probe（只在 probe 失敗時用）：`i915.force_probe=<pci-device-id>`
