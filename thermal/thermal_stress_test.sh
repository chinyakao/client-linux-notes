#!/usr/bin/env bash

# =========================
# Run by root: 
# sudo ./thermal_stress_test.sh
# sudo OUT_ROOT=./logs INTERVAL=1 CPU_WORKERS=8 ./thermal_stress_test.sh
# =========================

set -euo pipefail

# =========================
# Configurable parameters
# =========================
OUT_ROOT="${OUT_ROOT:-./logs}"
INTERVAL="${INTERVAL:-1}"               # seconds
CPU_WORKERS="${CPU_WORKERS:-4}"

# Stage definitions: (name duration_sec cpu_load)
# You can tune these per platform.
STAGES=(
  "warmup 300 60"
  "cross  300 90"
  "sustain 600 90"
  "cooldown 180 0"
)

CAPTURE_THERMALD_JOURNAL="${CAPTURE_THERMALD_JOURNAL:-1}"  # 1: enable, 0: disable
CAPTURE_DMESG_THERMAL="${CAPTURE_DMESG_THERMAL:-1}"        # 1: enable, 0: disable
CAPTURE_TURBOSTAT="${CAPTURE_TURBOSTAT:-1}"                # 1: enable if available

# =========================
# Helpers
# =========================
ts() { date +"%Y-%m-%d %H:%M:%S"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Safe read function
r() {
  local path="$1"
  if [[ -r "$path" ]]; then cat "$path" 2>/dev/null | tr -d '\n'
  else echo "NA"
  fi
}

# =========================
# Pre-checks
# =========================
need_cmd date
need_cmd awk
need_cmd sed
need_cmd stress-ng

if [[ "$CAPTURE_TURBOSTAT" -eq 1 ]]; then
  if ! command -v turbostat >/dev/null 2>&1; then
    echo "[WARN] turbostat not found; will skip turbostat capture."
    CAPTURE_TURBOSTAT=0
  fi
fi

if [[ "$CAPTURE_DMESG_THERMAL" -eq 1 ]]; then
  need_cmd dmesg
fi

if [[ "$CAPTURE_THERMALD_JOURNAL" -eq 1 ]]; then
  need_cmd journalctl
fi

# Many signals need root for best data (turbostat, dmidecode, journal)
if ! is_root; then
  echo "[WARN] Not running as root. Some captures may be limited."
  echo "       Recommended: sudo $0"
fi

RUN_ID="$(date +"%Y%m%d_%H%M%S")"
OUT_DIR="${OUT_ROOT}/${RUN_ID}"
mkdir -p "$OUT_DIR"

META="$OUT_DIR/meta.txt"
STEPS="$OUT_DIR/steps.log"
TZ_CSV="$OUT_DIR/thermal_zones.csv"
CD_CSV="$OUT_DIR/cooling_devices.csv"
CPUFREQ_CSV="$OUT_DIR/cpufreq.csv"
TURBO_CSV="$OUT_DIR/turbostat.csv"
THERMALD_LOG="$OUT_DIR/thermald_journal.log"
DMESG_LOG="$OUT_DIR/dmesg_thermal.log"

echo "[INFO] Output dir: $OUT_DIR"

# =========================
# Capture meta info
# =========================
{
  echo "run_id=$RUN_ID"
  echo "time=$(ts)"
  echo "uname=$(uname -a)"
  echo "cmdline=$(cat /proc/cmdline 2>/dev/null || true)"
  echo "thermald_status=$(systemctl is-active thermald 2>/dev/null || echo NA)"
  echo "thermald_version=$(thermald --version 2>/dev/null || echo NA)"
  echo "stressng_version=$(stress-ng --version 2>/dev/null | head -n1 || echo NA)"
  echo "turbostat_version=$(turbostat --version 2>/dev/null || echo NA)"
  if command -v dmidecode >/dev/null 2>&1; then
    echo "bios_vendor=$(dmidecode -s bios-vendor 2>/dev/null || echo NA)"
    echo "bios_version=$(dmidecode -s bios-version 2>/dev/null || echo NA)"
    echo "bios_date=$(dmidecode -s bios-release-date 2>/dev/null || echo NA)"
    echo "system_manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null || echo NA)"
    echo "system_product=$(dmidecode -s system-product-name 2>/dev/null || echo NA)"
  else
    echo "dmidecode=NA"
  fi
} | tee "$META" >/dev/null

# =========================
# Discover sysfs entries
# =========================
TZ_DIRS=(/sys/class/thermal/thermal_zone*)
CD_DIRS=(/sys/class/thermal/cooling_device*)

# CPUFreq policies (may not exist on some setups)
CPU_POLICIES=(/sys/devices/system/cpu/cpufreq/policy*)

# Write CSV headers
# thermal_zones.csv: time,zone,type,temp_mC,trip0_type,trip0_temp,...
{
  printf "time"
  for z in "${TZ_DIRS[@]}"; do
    [[ -d "$z" ]] || continue
    zn="$(basename "$z")"
    printf ",%s_type,%s_temp_mC" "$zn" "$zn"
    # include up to 10 trips if present
    for i in $(seq 0 9); do
