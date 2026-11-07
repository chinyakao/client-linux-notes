---
title: "Intel iGPU drop to 30 FPS"
parent: "Graphics & Platform"
grand_parent: "English"
nav_order: 1
lang: en
---

# Intel iGPU: Fullscreen Drops to 30 FPS
## Confirming the Graphics Driver Is Loaded, Then Finding What Halves the Frame Rate

## Symptom

- Intel integrated GPU on a laptop
- Display system: Xorg / X Window
- In fullscreen, the refresh rate / fps drops from 60 to 30 and the screen lags

## 0. Short Version

- 60 → 30 fps is usually **not** a lack of GPU performance. A power saving or sync mechanism is running at "half speed".
- Most common culprits:
  - PSR (Panel Self Refresh)
  - DRRS (Dynamic Refresh Rate Switching)
  - GuC / HuC firmware not loaded
  - Xorg fullscreen + compositor pipeline
- Work through it in order: is the driver bound → is it hardware rendering → which power saving feature halves the rate.

## 1. Is the iGPU Bound to a Kernel Driver?

Recent Intel GPUs use either `i915` or the newer `xe` driver, depending on the platform and kernel. The steps are the same; use the module name you see.

### 1.1 Find the device and its PCI ID

```bash
lspci -nn | grep -E "VGA|Display"
```

Note the `[8086:xxxx]` ID. Newer platforms can show more than one function; seeing only one is also normal.

### 1.2 Which driver is in use

```bash
lspci -nnk | grep -A3 -E "VGA|Display"
```

How to read it:

*   `Kernel driver in use: i915` (or `xe`) → the driver is attached
*   only `Kernel modules:` and no `driver in use` → probe failed, the device needs `force_probe`, or the module is blacklisted
*   no driver at all → the kernel is too old for this GPU, or the module is missing

### 1.3 Module loaded?

```bash
lsmod | grep -E "^(i915|xe)"
sudo modprobe i915   # load by hand for testing
```

### 1.4 Probe result in dmesg

```bash
dmesg | grep -i -E "i915|xe "
```

Keywords to watch for:

*   `Device is not supported` / `force_probe` → the kernel knows the ID but does not enable it by default
*   `Failed to load ... firmware` (DMC / GuC / HuC) → update `linux-firmware`

## 2. Did It Fall Back to Software Rendering (llvmpipe)?

```bash
glxinfo | grep -E "OpenGL renderer|OpenGL version"
ls -l /dev/dri
```

*   Mesa Intel renderer → hardware rendering
*   `llvmpipe` → CPU software rendering; go back to step 1
*   `/dev/dri` should have `card0` and `renderD128`

> A steady 30 fps is usually not llvmpipe (that is slow and uneven), but sync or power saving.

## 3. Why Exactly 30 fps?

**30 fps is a signal, not a coincidence.** It means the refresh rate / vblank was halved (60 → 30), not that rendering can't keep up.

Common causes:

*   PSR (Panel Self Refresh)
*   DRRS (switching between 60 / 48 / 30 Hz)
*   Display DC states / clock gating
*   Xorg Present / page flip / compositor treating the scene as static

## 4. Suspect No. 1: PSR

### 4.1 Check PSR status

```bash
sudo mount -t debugfs none /sys/kernel/debug
sudo cat /sys/kernel/debug/dri/0/i915_edp_psr_status
```

If it shows `PSR enabled` / `PSR2 enabled`, PSR is a strong suspect.

### 4.2 Verify by turning PSR off

Add to the kernel cmdline:

    i915.enable_psr=0

GRUB example:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_psr=0"
sudo update-grub
sudo reboot
```

Fullscreen back to 60 fps → PSR confirmed.

## 5. Suspect No. 2: DRRS

DRRS switches the panel between 60, 48, and 30 Hz. Turn it off to compare:

    i915.enable_drrs=0

> PSR and DRRS often show up together.

## 6. GuC / HuC Firmware

```bash
dmesg | grep -i -E "guc|huc|dmc"
```

Expected: `GuC firmware ... loaded`, `HuC firmware authenticated`. If loading fails, update `linux-firmware` first.

For testing, force-enable GuC/HuC:

    i915.enable_guc=3

## 7. Xorg / Compositor

### 7.1 Session type

```bash
echo $XDG_SESSION_TYPE
```

*   `x11` → more likely to hit this problem
*   `wayland` → refresh rate management is usually more stable

### 7.2 Compositor

```bash
picom --no-vsync
```

Or turn the compositor off and compare.

### 7.3 Xorg driver

On recent platforms use `modesetting`, not the old `intel` DDX:

```bash
grep -i "driver" /var/log/Xorg.0.log | head
```

## 8. Rule Out a Lack of GPU Performance

```bash
sudo cat /sys/kernel/debug/dri/0/i915_frequency_info
sudo apt install intel-gpu-tools
sudo intel_gpu_top
```

If GPU usage is low and the GPU clock stays low while fps is fixed at 30, it is a power or display issue, not performance.

## 9. A/B Testing

```text
i915.enable_psr=0
i915.enable_drrs=0
i915.enable_guc=3
```

Change **one parameter at a time** and record the result, so you know which one fixed it.

## 10. Long-Term Fix

Switching to a Wayland session makes the 60 → 30 fps problem go away in most cases.

## 11. Quick Debug Checklist

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

## 12. Kernel cmdline Cheat Sheet

*   Disable PSR: `i915.enable_psr=0`
*   Disable DRRS: `i915.enable_drrs=0`
*   Enable GuC/HuC: `i915.enable_guc=3`
*   Force probe (only when probing fails): `i915.force_probe=<pci-device-id>`
