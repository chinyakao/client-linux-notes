---
title: "電源管理"
parent: "中文"
nav_order: 2
has_children: true
lang: zh
---

# 電源管理

Linux 如何睡眠與 idle，以及要看哪些數據才能判斷系統真的進入硬體睡眠。

- [s2idle、S0ix 與 S3](s2idle-s0ix.md)
- [cpuidle 與 C-state](cpuidle.md)

在多次 suspend 循環中收集 residency 計數器（Intel `pmc_core`、AMD `amd_pmc`）的腳本，放在
[linux_tool_script/stress](https://github.com/chinyakao/linux_tool_script/tree/main/stress)。
