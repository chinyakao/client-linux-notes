---
title: "Power Management"
parent: "English"
nav_order: 2
has_children: true
lang: en
---

# Power Management

How Linux suspends and idles, and what to read to tell whether a system really
reached hardware sleep.

- [s2idle, S0ix, and S3](s2idle-s0ix.md)
- [cpuidle and C-states](cpuidle.md)

Scripts that collect suspend residency counters (Intel `pmc_core`, AMD
`amd_pmc`) over repeated suspend cycles are in
[linux_tool_script/stress](https://github.com/chinyakao/linux_tool_script/tree/main/stress).
