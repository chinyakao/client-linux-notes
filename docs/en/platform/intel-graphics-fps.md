---
title: "Intel iGPU drop to 30 FPS"
parent: "Graphics & Platform"
grand_parent: "English"
nav_order: 1
lang: en
---

# Intel iGPU (PCI ID: 8086:xxxx) + Linux kernel
## Confirming i915 Is Loaded and Troubleshooting a Fullscreen Drop to 30 FPS

## Context

- New-generation Intel iGPU (this machine shows only one PCI ID: `8086:xxxx`)
- Linux kernel: `<version>`
- Display system: Xorg / X Window
- Symptom: **in fullscreen, refresh rate / fps drops from 60 to 30 and the screen lags**



## 0. One-Line Conclusion (for future me)

- ✅ **kernel almost certainly supports <device-id>**
- ❌ **60 → 30 fps is usually not a lack of performance; a power saving / sync mechanism is running at "half speed"**
- 🎯 Most common culprits:
  - PSR (Panel Self Refresh)
  - DRRS (Dynamic Refresh Rate Switching)
  - GuC / HuC firmware
  - Xorg fullscreen + compositor pipeline



## 1. First Check: Is the iGPU Bound to i915?

### 1.1 Confirm the PCI ID

```bash
lspci -nn | grep -E "VGA|Display"
```

You should see something like:

    Intel Corporation Device [8086:xxxx]

> New platforms may have multiple functions / tiles; seeing only one <device-id> is also normal.



### 1.2 Confirm the kernel driver in use

```bash
lspci -nnk | grep -A3 -E "VGA|Display"
```

Ideal:

    Kernel driver in use: i915
    Kernel modules: i915

How to read it:

*   ✅ `driver in use: i915` → attached
*   ⚠️ only `Kernel modules` → probe failed / force\_probe / blacklist
*   ❌ no i915 → kernel / module problem



### 1.3 Confirm the i915 module

```bash
lsmod | grep ^i915
```

Load it by hand for testing:

```bash
sudo modprobe i915
```



### 1.4 Check the probe result in dmesg

```bash
dmesg | grep -i i915
```

Keywords to watch for:

*   `Device is not supported`
*   `force_probe`
*   `Failed to load ... firmware` (DMC / GuC / HuC)



## 2. Check Whether It Fell Back to llvmpipe (Software Rendering)

### 2.1 OpenGL renderer

```bash
glxinfo | grep -E "OpenGL renderer|OpenGL version"
```

*   ✅ Mesa Intel renderer
*   ❌ `llvmpipe` → CPU software rendering

> A steady 30 fps is usually not llvmpipe, but sync / power saving.



### 2.2 DRM device

```bash
ls -l /dev/dri
```

You should see `card0` and `renderD128`.



## 3. Why Exactly 30 fps?

**30 fps is a signal, not a coincidence.**

It means:

*   the refresh rate / vblank was halved (60 → 30)
*   not that GPU rendering can't keep up

Common causes:

*   PSR (Panel Self Refresh)
*   DRRS (switching between 60 / 48 / 30 Hz)
*   Display DC states / clock gating
*   Xorg Present / page flip / compositor misjudging a static scene



## 4. Suspect No. 1: PSR

### 4.1 Check PSR status

```bash
sudo mount -t debugfs none /sys/kernel/debug
cat /sys/kernel/debug/dri/0/i915_edp_psr_status
```

If it shows `PSR enabled` / `PSR2 enabled` → highly suspicious.



### 4.2 Verify: turn PSR off

Kernel cmdline:

    i915.enable_psr=0

GRUB example:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"
sudo update-grub
sudo reboot
```

✅ Fullscreen back to 60 fps → **PSR confirmed**



## 5. Suspect No. 2: DRRS

DRRS switches between:

*   60 Hz
*   48 Hz
*   30 Hz

Turn DRRS off:

    i915.enable_drrs=0

> A common case is **PSR + DRRS together**.



## 6. GuC / HuC firmware

### 6.1 Check firmware status

```bash
dmesg | grep -i -E "guc|huc|dmc"
```

Ideal messages:

*   `GuC firmware loaded`
*   `HuC firmware authenticated`

If loading fails, update `linux-firmware` first.



### 6.2 (For testing) force-enable GuC

    i915.enable_guc=3



## 7. Xorg / Compositor Problems

### 7.1 Session type

```bash
echo $XDG_SESSION_TYPE
```

*   `x11`: more likely to hit problems
*   `wayland`: more stable refresh rate management



### 7.2 Compositor (picom)

```bash
picom --no-vsync
```

Or turn the compositor off to compare.



### 7.3 Xorg driver

On new platforms, use `modesetting` and avoid the old `intel` DDX.

```bash
grep -i "driver" /var/log/Xorg.0.log | head
```



## 8. Confirm It Is Not a Lack of GPU Performance

### 8.1 GPU clock

```bash
cat /sys/kernel/debug/dri/0/i915_frequency_info
```

GPU clock stays low in fullscreen → a power / display issue.



### 8.2 Live view

```bash
sudo apt install intel-gpu-tools
intel_gpu_top
```

Signs:

*   GPU usage is not high
*   yet fps is fixed at 30



## 9. A Stable Parameter Set for Xorg

```text
i915.enable_psr=0
i915.enable_drrs=0
i915.enable_guc=3
```

Change one at a time for A/B testing.



## 10. Long-Term Fix

👉 **Switch to Wayland**

In most cases the 60 → 30 fps problem simply goes away.



## 11. Quick Debug Checklist

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



## 12. Kernel cmdline Cheat Sheet

*   Disable PSR: `i915.enable_psr=0`
*   Disable DRRS: `i915.enable_drrs=0`
*   Enable GuC/HuC: `i915.enable_guc=3`
*   Force probe (only when probing fails): `i915.force_probe=<pci-device-id>`
