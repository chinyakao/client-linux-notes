---
title: Power Management
nav_order: 3
has_children: true
---

# Power Management

How Linux suspends and idles, and what to read to tell whether a system really
reached hardware sleep.

- [s2idle、S0ix 與 S3（中文）](s2idle-s0ix_zh.md)
- [cpuidle and C-states](cpuidle.md) / [中文](cpuidle_zh.md)

Scripts that collect suspend residency counters (Intel `pmc_core`, AMD
`amd_pmc`) over repeated suspend cycles are in
[linux_tool_script/stress](https://github.com/chinyakao/linux_tool_script/tree/main/stress).
