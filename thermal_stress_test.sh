#!/usr/bin/env bash

# =========================
# Pre-install:
# sudo apt-get install -y stress-ng linux-tools-common linux-tools-generic
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
      [[ -e "$z/trip_point_${i}_type" ]] || continue
      printf ",%s_trip%d_type,%s_trip%d_temp_mC" "$zn" "$i" "$zn" "$i"
    done
  done
  printf "\n"
} > "$TZ_CSV"

# cooling_devices.csv: time,cd,type,cur_state,max_state (wide format)
{
  printf "time"
  for c in "${CD_DIRS[@]}"; do
    [[ -d "$c" ]] || continue
    cn="$(basename "$c")"
    printf ",%s_type,%s_cur,%s_max" "$cn" "$cn" "$cn"
  done
  printf "\n"
} > "$CD_CSV"

# cpufreq.csv: time,policy,cur_khz,min_khz,max_khz,gov
{
  echo "time,policy,cur_khz,min_khz,max_khz,governor"
} > "$CPUFREQ_CSV"

# =========================
# Background monitors
# =========================
MON_PID=""
DMESG_PID=""
JOURNAL_PID=""
TURBO_PID=""

monitor_sysfs() {
  while true; do
    local now
    now="$(ts)"

    # thermal zones row
    {
      printf "%s" "$now"
      for z in "${TZ_DIRS[@]}"; do
        [[ -d "$z" ]] || continue
        printf ",%s,%s" "$(r "$z/type")" "$(r "$z/temp")"
        for i in $(seq 0 9); do
          [[ -e "$z/trip_point_${i}_type" ]] || continue
          printf ",%s,%s" "$(r "$z/trip_point_${i}_type")" "$(r "$z/trip_point_${i}_temp")"
        done
      done
      printf "\n"
    } >> "$TZ_CSV"

    # cooling devices row
    {
      printf "%s" "$now"
      for c in "${CD_DIRS[@]}"; do
        [[ -d "$c" ]] || continue
        printf ",%s,%s,%s" "$(r "$c/type")" "$(r "$c/cur_state")" "$(r "$c/max_state")"
      done
      printf "\n"
    } >> "$CD_CSV"

    # cpufreq (long format; one row per policy)
    for p in "${CPU_POLICIES[@]}"; do
      [[ -d "$p" ]] || continue
      local pn cur mn mx gov
      pn="$(basename "$p")"
      cur="$(r "$p/scaling_cur_freq")"
      mn="$(r "$p/scaling_min_freq")"
      mx="$(r "$p/scaling_max_freq")"
      gov="$(r "$p/scaling_governor")"
      echo "$now,$pn,$cur,$mn,$mx,$gov" >> "$CPUFREQ_CSV"
    done

    sleep "$INTERVAL"
  done
}

start_dmesg_capture() {
  # capture thermal/throttle related kernel messages
  # Use --level if supported? keep it simple.
  dmesg -wT | stdbuf -oL -eL grep -iE "thermal|thrott|PROCHOT|trip|powerclamp|cpu.*temp" \
    > "$DMESG_LOG" &
  DMESG_PID=$!
}

start_thermald_journal_capture() {
  journalctl -u thermald -f --no-pager > "$THERMALD_LOG" &
  JOURNAL_PID=$!
}

start_turbostat_capture() {
  # turbostat CSV output: keep raw for parsing
  # Some systems require modprobe msr
  modprobe msr 2>/dev/null || true
  turbostat --quiet --interval "$INTERVAL" --out "$TURBO_CSV" &
  TURBO_PID=$!
}

cleanup() {
  echo "[INFO] Cleaning up..."
  [[ -n "${MON_PID}" ]] && kill "$MON_PID" 2>/dev/null || true
  [[ -n "${DMESG_PID}" ]] && kill "$DMESG_PID" 2>/dev/null || true
  [[ -n "${JOURNAL_PID}" ]] && kill "$JOURNAL_PID" 2>/dev/null || true
  [[ -n "${TURBO_PID}" ]] && kill "$TURBO_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "[INFO] Starting background monitors..."
monitor_sysfs &
MON_PID=$!

if [[ "$CAPTURE_DMESG_THERMAL" -eq 1 ]]; then
  echo "[INFO] Capturing dmesg thermal..."
  start_dmesg_capture
fi

if [[ "$CAPTURE_THERMALD_JOURNAL" -eq 1 ]]; then
  echo "[INFO] Capturing thermald journal..."
  start_thermald_journal_capture
fi

if [[ "$CAPTURE_TURBOSTAT" -eq 1 ]]; then
  echo "[INFO] Capturing turbostat..."
  start_turbostat_capture
fi

# =========================
# Run stages
# =========================
echo "[INFO] Running stages..."
echo "start $(ts)" | tee -a "$STEPS"

for s in "${STAGES[@]}"; do
  name="$(echo "$s" | awk '{print $1}')"
  dur="$(echo "$s" | awk '{print $2}')"
  load="$(echo "$s" | awk '{print $3}')"

  echo "stage_begin,$name,$(ts),duration=${dur},load=${load}" | tee -a "$STEPS"

  if [[ "$name" == "cooldown" || "$load" -eq 0 ]]; then
    sleep "$dur"
  else
    # Use stress-ng cpu-load to shape load and make it repeatable
    stress-ng --cpu "$CPU_WORKERS" --cpu-load "$load" --timeout "${dur}s" --metrics-brief \
      >> "$OUT_DIR/stressng_${name}.log" 2>&1 || true
  fi

  echo "stage_end,$name,$(ts)" | tee -a "$STEPS"
done

echo "end $(ts)" | tee -a "$STEPS"

echo "[INFO] Done. Logs saved to: $OUT_DIR"
echo "[INFO] Key files: $TZ_CSV $CD_CSV $CPUFREQ_CSV $TURBO_CSV $DMESG_LOG $THERMALD_LOG"
