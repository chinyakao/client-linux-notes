---
title: "中文"
nav_order: 2
has_children: true
lang: zh
---

# Linux Platform Enablement 筆記

整理我在 Linux 平台工程工作上用到和學到的東西：編譯與測試 kernel，以及除錯 driver、電源、散熱、顯示相關問題。每一頁都有英文與繁體中文版本，可以用頁面上方的切換連結切換。

| 分類 | 內容 |
|---|---|
| [編譯 Kernel](kernel-build/index.md) | 用 Docker 編譯 mainline、drm-tip、kernel.org、Ubuntu OEM kernel，產出可安裝的 `.deb` 測試 kernel；patch、config、tmux。 |
| [電源管理](power/index.md) | s2idle、S0ix 與 S3 的差別、`/sys/power/mem_sleep`、rtcwake、cpuidle 與 C-state。 |
| [散熱](thermal/index.md) | 從 ACPI DPTF 表到 thermald 的 Linux 散熱架構、PL1/PL2 功耗上限、分階段散熱壓力測試。 |
| [顯示與平台](platform/index.md) | Intel iGPU 全螢幕 FPS 掉速排查、Intel 核心類型與 BIOS 選項。 |
| [除錯](debugging/index.md) | Kernel panic、apport、core dump。 |

## 相關 repo

- [linux-device-driver](https://github.com/chinyakao/linux-device-driver)：從零寫的 kernel driver，在 QEMU 裡測試。
- [linux_tool_script](https://github.com/chinyakao/linux_tool_script)：壓力測試與 log 收集腳本（suspend residency、網路重開機）。
- [fwupd](https://github.com/fwupd/fwupd)：對 `mediatek-scaler` plugin 的上游貢獻（隨 1.9.31 與 2.0.13 發佈）。
