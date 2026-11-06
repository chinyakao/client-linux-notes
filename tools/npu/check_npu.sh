#!/usr/bin/env bash
# =========================
# Check that the Intel NPU (intel_vpu / accel) is ready for OpenVINO.
# Usage: ./check_npu.sh        (some lines need sudo to read dmesg)
# =========================
set -uo pipefail

ok()   { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; }

echo "== Kernel and module =="
echo "  kernel: $(uname -r)"
# /sys/module is more reliable than `lsmod | grep -q` (grep -q exits early and
# lsmod gets SIGPIPE, which pipefail reports as a failure)
if [ -d /sys/module/intel_vpu ]; then ok "intel_vpu loaded"; else fail "intel_vpu not loaded (sudo modprobe intel_vpu; needs kernel 6.8+ for Meteor Lake)"; fi
lspci -nn 2>/dev/null | grep -iE 'npu|vpu|processing accelerator' | sed 's/^/  pci: /'

echo "== Device node and permissions =="
if [ -e /dev/accel/accel0 ]; then
  ok "$(ls -l /dev/accel/accel0)"
  if [ -r /dev/accel/accel0 ] && [ -w /dev/accel/accel0 ]; then ok "current user can open accel0"
  else fail "no rw access: sudo usermod -aG render $USER, then log out and in"; fi
else
  fail "/dev/accel/accel0 missing"
fi
id -nG | grep -qw render && ok "user in render group" || warn "user not in render group"

echo "== Firmware =="
ls /lib/firmware/intel/vpu/ 2>/dev/null | sed 's/^/  fw file: /' || warn "no /lib/firmware/intel/vpu/"
dmesg 2>/dev/null | grep -iE 'intel_vpu|ivpu' | tail -5 | sed 's/^/  dmesg: /' || true
[ -z "$(dmesg 2>/dev/null | head -1)" ] && warn "dmesg not readable, rerun with sudo to see firmware version"

echo "== User-space packages (intel/linux-npu-driver) =="
if command -v dpkg-query >/dev/null; then
  pkgs=$(dpkg-query -W -f='${Status} ${Package} ${Version}\n' 2>/dev/null \
    | awk '/^install ok installed/ && $4 ~ /^(intel-driver-compiler-npu|intel-fw-npu|intel-level-zero-npu|libze1|libze-intel-gpu1|level-zero)/ {printf "  %-35s %s\n", $4, $5}')
  if [ -n "$pkgs" ]; then echo "$pkgs"
  else fail "no NPU user-space packages: install the .deb files from github.com/intel/linux-npu-driver/releases"; fi
  echo "$pkgs" | grep -q intel-level-zero-npu || warn "intel-level-zero-npu missing: OpenVINO will not list NPU"
else
  warn "dpkg-query not available (not a Debian/Ubuntu system?)"
fi

echo "== sysfs counters used by the benchmark =="
for f in /sys/class/accel/accel0/device/npu_busy_time_us; do
  if [ -r "$f" ]; then ok "$f = $(cat "$f")"; else warn "$f not available (older kernel?)"; fi
done
for d in /sys/class/powercap/intel-rapl:*; do
  [ -e "$d/name" ] || continue
  if [ -r "$d/energy_uj" ]; then ok "$(basename "$d") $(cat "$d/name") readable"
  else warn "$(basename "$d") $(cat "$d/name") energy_uj needs root"; fi
done

echo "== OpenVINO view =="
python3 - <<'PY' 2>/dev/null || warn "python openvino not installed (pip install openvino)"
import openvino as ov
core = ov.Core()
for d in core.available_devices:
    print(f"  {d:6s} {core.get_property(d, 'FULL_DEVICE_NAME')}")
PY
