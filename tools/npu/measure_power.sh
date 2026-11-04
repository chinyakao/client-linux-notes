#!/usr/bin/env bash
# =========================
# Run any command while logging package / core / GPU power (turbostat)
# and NPU busy time, then print averages.
#
# Pre-install: sudo apt-get install -y linux-tools-common linux-tools-$(uname -r)
# Usage (root is needed for turbostat and RAPL):
#   sudo ./measure_power.sh -- python bench/bench_embed.py --devices NPU
#   sudo OUT_DIR=./logs INTERVAL=0.5 IDLE_SEC=10 ./measure_power.sh -- <cmd>
# Output: $OUT_DIR/<timestamp>/{turbostat.tsv,npu_busy.csv,cmd.log,summary.txt}
# =========================
set -euo pipefail

OUT_DIR="${OUT_DIR:-./logs}"
INTERVAL="${INTERVAL:-1}"     # seconds
IDLE_SEC="${IDLE_SEC:-10}"    # idle baseline before the command
NPU_BUSY=/sys/class/accel/accel0/device/npu_busy_time_us

[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "usage: $0 -- <command ...>"; exit 1; }
command -v turbostat >/dev/null || { echo "turbostat not found"; exit 1; }

RUN="$OUT_DIR/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN"

log_npu() {  # time,busy_us every INTERVAL
  echo "time,phase,npu_busy_us" > "$RUN/npu_busy.csv"
  while :; do
    phase=$(cat "$RUN/phase" 2>/dev/null || echo "?")
    busy=$( [ -r "$NPU_BUSY" ] && cat "$NPU_BUSY" || echo "")
    echo "$(date +%s.%N),$phase,$busy" >> "$RUN/npu_busy.csv"
    sleep "$INTERVAL"
  done
}

echo idle > "$RUN/phase"
turbostat --quiet --Summary --show Time_Of_Day_Seconds,Busy%,Bzy_MHz,PkgWatt,CorWatt,GFXWatt,PkgTmp \
  --interval "$INTERVAL" -o "$RUN/turbostat.tsv" &
TS_PID=$!
log_npu & NPU_PID=$!
trap 'kill $TS_PID $NPU_PID 2>/dev/null || true' EXIT

echo "idle baseline ${IDLE_SEC}s ..."
T_IDLE=$(date +%s.%N); sleep "$IDLE_SEC"
echo run > "$RUN/phase"
T_RUN=$(date +%s.%N)
echo "running: $*"
set +e
sudo -E -u "${SUDO_USER:-$USER}" "$@" 2>&1 | tee "$RUN/cmd.log"
RC=${PIPESTATUS[0]}
set -e
T_END=$(date +%s.%N)
sleep "$INTERVAL"
kill $TS_PID $NPU_PID 2>/dev/null || true; wait 2>/dev/null || true

python3 - "$RUN" "$T_IDLE" "$T_RUN" "$T_END" <<'PY' | tee "$RUN/summary.txt"
import csv, sys
run, t_idle, t_run, t_end = sys.argv[1], *map(float, sys.argv[2:])
rows = [r for r in csv.DictReader(open(f"{run}/turbostat.tsv"), delimiter="\t")
        if r.get("Time_Of_Day_Seconds", "").replace(".", "").isdigit()]
def avg(col, lo, hi):
    v = [float(r[col]) for r in rows if lo <= float(r["Time_Of_Day_Seconds"]) <= hi and r.get(col) not in (None, "", "-")]
    return sum(v) / len(v) if v else float("nan")
print(f"{'':8s} {'PkgWatt':>8s} {'CorWatt':>8s} {'GFXWatt':>8s} {'Busy%':>6s}")
for name, lo, hi in (("idle", t_idle, t_run), ("run", t_run, t_end)):
    print(f"{name:8s} " + " ".join(f"{avg(c, lo, hi):8.2f}" for c in ("PkgWatt", "CorWatt", "GFXWatt")) + f" {avg('Busy%', lo, hi):6.1f}")
pts = [(float(r["time"]), int(r["npu_busy_us"])) for r in csv.DictReader(open(f"{run}/npu_busy.csv"))
       if r["npu_busy_us"] and t_run <= float(r["time"]) <= t_end]
if len(pts) >= 2:
    print(f"NPU busy during run: {(pts[-1][1] - pts[0][1]) / 1e6 / (pts[-1][0] - pts[0][0]) * 100:.1f}%")
else:
    print("NPU busy: not available")
print(f"run time: {t_end - t_run:.1f}s, energy above idle ~ "
      f"{(avg('PkgWatt', t_run, t_end) - avg('PkgWatt', t_idle, t_run)) * (t_end - t_run):.1f} J")
PY
echo "logs: $RUN (exit code $RC)"
exit "$RC"
