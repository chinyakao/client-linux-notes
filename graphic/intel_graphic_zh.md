# Intel iGPU（PCI ID: 8086:7DD1）+ Linux Kernel 6.17  
## i915 Driver 載入確認與 Fullscreen 掉到 30 FPS 排查筆記

## 使用情境

- Intel 新世代 iGPU（此機器僅看到一個 PCI ID：`8086:7DD1`）
- Linux kernel：`6.17`
- 顯示系統：Xorg / XWindow
- 症狀：**進入 fullscreen 時，refresh rate / fps 從 60 掉到 30，畫面 lag**



## 0. 一句話結論（給未來的自己）

- ✅ **Kernel 6.17 本身幾乎一定支援 7DD1**
- ❌ **60 → 30 fps 通常不是效能不足，而是被省電 / 同步機制「半速」了**
- 🎯 最常見兇手：
  - PSR（Panel Self Refresh）
  - DRRS（Dynamic Refresh Rate Switching）
  - GuC / HuC firmware
  - Xorg fullscreen + compositor pipeline



## 1. 初步判斷：iGPU 是否被 i915 接管

### 1.1 確認 PCI ID

```bash
lspci -nn | grep -E "VGA|Display"
````

應看到類似：

    Intel Corporation Device [8086:7dd1]

> 新世代平台可能有多 function / tile；僅看到一個 7DD1 亦屬正常。



### 1.2 確認 kernel driver in use

```bash
lspci -nnk | grep -A3 -E "VGA|Display"
```

理想狀態：

    Kernel driver in use: i915
    Kernel modules: i915

判讀：

*   ✅ `driver in use: i915` → 已 attach
*   ⚠️ 只有 `Kernel modules` → probe 失敗 / force\_probe / blacklist
*   ❌ 沒有 i915 → kernel / module 問題



### 1.3 確認 i915 module

```bash
lsmod | grep ^i915
```

測試用手動載入：

```bash
sudo modprobe i915
```



### 1.4 檢查 dmesg probe 結果

```bash
dmesg | grep -i i915
```

注意關鍵字：

*   `Device is not supported`
*   `force_probe`
*   `Failed to load ... firmware`（DMC / GuC / HuC）



## 2. 確認是否落到 llvmpipe（軟繪圖）

### 2.1 OpenGL renderer

```bash
glxinfo | grep -E "OpenGL renderer|OpenGL version"
```

*   ✅ Mesa Intel renderer
*   ❌ `llvmpipe` → CPU 軟繪圖

> 穩定卡在 30 fps 通常不是 llvmpipe，而是同步 / 省電。



### 2.2 DRM device

```bash
ls -l /dev/dri
```

應看到 `card0`、`renderD128`。



## 3. 為什麼會「剛好掉到 30 fps」？

**30 fps 是訊號，不是巧合。**

代表：

*   refresh rate / vblank 被 halved（60 → 30）
*   而非 GPU rendering 跑不動

常見原因：

*   PSR（Panel Self Refresh）
*   DRRS（60 / 48 / 30 Hz 切換）
*   Display DC states / clock gating
*   Xorg Present / page flip / compositor 誤判 static scene



## 4. 第一順位兇手：PSR

### 4.1 檢查 PSR 狀態

```bash
sudo mount -t debugfs none /sys/kernel/debug
cat /sys/kernel/debug/dri/0/i915_edp_psr_status
```

若顯示 `PSR enabled` / `PSR2 enabled` → 高度可疑。



### 4.2 驗證：關掉 PSR

Kernel cmdline：

    i915.enable_psr=0

GRUB 範例：

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"
sudo update-grub
sudo reboot
```

✅ Fullscreen 回到 60 fps → **PSR 確診**



## 5. 第二順位兇手：DRRS

DRRS 會在以下間切換：

*   60 Hz
*   48 Hz
*   30 Hz

關閉 DRRS：

    i915.enable_drrs=0

> 常見情況是 **PSR + DRRS 疊加**。



## 6. GuC / HuC firmware

### 6.1 檢查 firmware 狀態

```bash
dmesg | grep -i -E "guc|huc|dmc"
```

理想訊息：

*   `GuC firmware loaded`
*   `HuC firmware authenticated`

失敗時先更新 `linux-firmware`。



### 6.2（測試用）強制啟用 GuC

    i915.enable_guc=3



## 7. Xorg / compositor 問題

### 7.1 Session type

```bash
echo $XDG_SESSION_TYPE
```

*   `x11`：較容易踩雷
*   `wayland`：刷新率管理較穩



### 7.2 Compositor（picom）

```bash
picom --no-vsync
```

或關閉 compositor 做比較。



### 7.3 Xorg driver

新平台建議使用 `modesetting`，避免舊的 `intel` DDX。

```bash
grep -i "driver" /var/log/Xorg.0.log | head
```



## 8. 確認不是 GPU 效能不足

### 8.1 GPU clock

```bash
cat /sys/kernel/debug/dri/0/i915_frequency_info
```

Fullscreen 時 GPU clock 長期偏低 → power / display issue。



### 8.2 即時觀察

```bash
sudo apt install intel-gpu-tools
intel_gpu_top
```

特徵：

*   GPU usage 不高
*   fps 卻固定 30



## 9. Xorg 下的穩定建議參數組合

```text
i915.enable_psr=0
i915.enable_drrs=0
i915.enable_guc=3
```

建議一次只調一個做 A/B test。



## 10. 長期解法

👉 **改用 Wayland**

大多數情況下，60 → 30 fps 問題會直接消失。



## 11. 快速 Debug Checklist

```bash
uname -r
lspci -nn | grep -E "VGA|Display"
lspci -nnk | grep -A3 -E "VGA|Display"
lsmod | grep ^i915
dmesg | grep -i i915
dmesg | grep -i -E "guc|huc|dmc|psr|drrs"
glxinfo | grep -E "OpenGL renderer|OpenGL version"
sudo mount -t debugfs none /sys/kernel/debug
cat /sys/kernel/debug/dri/0/i915_edp_psr_status
cat /sys/kernel/debug/dri/0/i915_frequency_info
intel_gpu_top
echo $XDG_SESSION_TYPE
```



## 12. Kernel cmdline 速查

*   關 PSR：`i915.enable_psr=0`
*   關 DRRS：`i915.enable_drrs=0`
*   開 GuC/HuC：`i915.enable_guc=3`
*   force probe（僅 probe 失敗時）：`i915.force_probe=7DD1`
