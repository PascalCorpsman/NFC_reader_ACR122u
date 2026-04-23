#!/usr/bin/env bash
set -u

VID="072f"
PID="2200"
READER_NAME="ACS ACR122U"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; }
info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing command: $1"
    return 1
  fi
  return 0
}

all_ok=1
usb_ok=0
pcsc_scan_ok=0
pn533_bound=0
iface_bound=""

printf "\nNFC Reader Health Check (ACR122U)\n"
printf "================================\n\n"

missing=0
for cmd in lsusb systemctl timeout pcsc_scan; do
  if ! need_cmd "$cmd"; then
    missing=1
  fi
done

if [[ "$missing" -eq 1 ]]; then
  printf "\nInstall required tools and retry:\n"
  printf "  sudo apt update && sudo apt install -y usbutils pcscd pcsc-tools libccid\n"
  exit 2
fi

if lsusb | grep -qi "${VID}:${PID}"; then
  pass "USB device ${VID}:${PID} is visible in lsusb."
  usb_ok=1
else
  fail "USB device ${VID}:${PID} not found in lsusb."
  all_ok=0
fi

DEV=""
for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" ]] || continue
  v=$(cat "$d/idVendor" 2>/dev/null || true)
  p=$(cat "$d/idProduct" 2>/dev/null || true)
  if [[ "$v" == "$VID" && "$p" == "$PID" ]]; then
    DEV="$d"
    break
  fi
done

if [[ -n "$DEV" ]]; then
  DEV_BASENAME=$(basename "$DEV")
  pass "Sysfs device path found: $DEV"

  if [[ -f "$DEV/power/control" ]]; then
    power_control=$(cat "$DEV/power/control" 2>/dev/null || true)
    info "USB power.control = $power_control"
    if [[ "$power_control" != "on" ]]; then
      warn "power.control is not 'on'. This can cause timeouts on some ACR122U setups."
    fi
  fi

  if [[ -f "$DEV/authorized" ]]; then
    auth=$(cat "$DEV/authorized" 2>/dev/null || true)
    info "USB authorized = $auth"
  fi
else
  warn "Could not resolve sysfs path for ${VID}:${PID}."
fi

if [[ -d /sys/bus/usb/drivers/pn533_usb ]]; then
  while IFS= read -r iface; do
    [[ -n "$iface" ]] || continue
    if [[ -n "$DEV" && "$iface" == "${DEV_BASENAME}:"* ]]; then
      pn533_bound=1
      iface_bound="$iface"
      break
    fi
  done < <(for x in /sys/bus/usb/drivers/pn533_usb/*:*; do [[ -L "$x" ]] && basename "$x"; done 2>/dev/null)
fi

if [[ "$pn533_bound" -eq 1 ]]; then
  fail "Reader is currently bound to pn533_usb ($iface_bound). pcscd cannot claim it."
  all_ok=0
else
  pass "Reader is not bound to pn533_usb."
fi

pcsc_socket_state=$(systemctl is-active pcscd.socket 2>/dev/null || true)
pcsc_service_state=$(systemctl is-active pcscd 2>/dev/null || true)

if [[ "$pcsc_socket_state" == "active" ]]; then
  pass "pcscd.socket is active."
else
  warn "pcscd.socket is not active ($pcsc_socket_state)."
  all_ok=0
fi

if [[ "$pcsc_service_state" == "active" ]]; then
  pass "pcscd service is active."
else
  info "pcscd service is $pcsc_service_state (can still be normal with socket activation)."
fi

info "Running short pcsc_scan probe (6 seconds)..."
scan_out=$(timeout 6s pcsc_scan 2>&1 || true)

if echo "$scan_out" | grep -q "$READER_NAME"; then
  pass "pcsc_scan detected reader: $READER_NAME"
  pcsc_scan_ok=1
else
  fail "pcsc_scan did not detect $READER_NAME in 6 seconds."
  all_ok=0
fi

printf "\nSummary\n"
printf "%s\n" "-------"
printf "USB present:        %s\n" "$usb_ok"
printf "pn533 bound:        %s\n" "$pn533_bound"
printf "pcsc_scan detected: %s\n" "$pcsc_scan_ok"

if [[ "$all_ok" -eq 1 ]]; then
  printf "\n${GREEN}System looks good. Reader should be usable.${NC}\n"
  exit 0
fi

printf "\nSuggested fixes\n"
printf "%s\n" "--------------"

if [[ "$usb_ok" -eq 0 ]]; then
  printf "- Replug reader and use a direct laptop USB port (avoid passive hubs).\n"
fi

if [[ "$pn533_bound" -eq 1 ]]; then
  printf "- Unbind from pn533_usb:\n"
  printf "    echo -n \"%s\" | sudo tee /sys/bus/usb/drivers/pn533_usb/unbind\n" "$iface_bound"
fi

if [[ "$pcsc_scan_ok" -eq 0 ]]; then
  printf "- Restart pcsc stack and retry:\n"
  printf "    sudo systemctl restart pcscd\n"
  printf "    pcsc_scan\n"
  if [[ -n "$DEV" ]]; then
    printf "- If still failing, force USB re-enumeration:\n"
    printf "    sudo systemctl stop pcscd pcscd.socket\n"
    printf "    echo 0 | sudo tee %s/authorized\n" "$DEV"
    printf "    echo 1 | sudo tee %s/authorized\n" "$DEV"
    printf "    echo on | sudo tee %s/power/control\n" "$DEV"
    printf "    sudo systemctl start pcscd.socket\n"
    printf "    pcsc_scan\n"
  fi
fi

exit 1
