---
title: "Thermal stress test"
parent: "Thermal"
grand_parent: "English"
nav_order: 5
lang: en
---

# Thermal Stress Test

Two scripts in the repository root measure how a platform heats up and cools
down, and compare two runs (for example, two BIOS versions).

## thermal_stress_test.sh

[Source](https://github.com/chinyakao/linux-platform-enablement/blob/main/thermal_stress_test.sh)

Runs a staged CPU load with `stress-ng` and logs, once per interval:

| File | Content |
|---|---|
| `thermal_zones.csv` | Temperature and trip points of every thermal zone |
| `cooling_devices.csv` | Current and maximum state of every cooling device |
| `cpufreq.csv` | Current, min, and max frequency and governor per policy |
| `turbostat.csv` | Package power and C-states (if turbostat is installed) |
| `thermald_journal.log` | thermald log for the run |

Default stages (name, seconds, CPU load %): warmup 300 60, cross 300 90,
sustain 600 90, cooldown 180 0.

```bash
sudo apt-get install -y stress-ng linux-tools-common linux-tools-generic
sudo OUT_ROOT=./logs INTERVAL=1 CPU_WORKERS=8 ./thermal_stress_test.sh
```

## analyze_compare.py

[Source](https://github.com/chinyakao/linux-platform-enablement/blob/main/analyze_compare.py)

Summarizes a run (hottest zones, peak cooling state, lowest CPU frequency) or
compares two runs.

```bash
python3 analyze_compare.py logs/runA [logs/runB]
```
