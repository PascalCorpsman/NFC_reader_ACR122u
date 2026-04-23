#!/usr/bin/env bash
set -euo pipefail

VID="072f"
PID="2200"
BLACKLIST_FILE="/etc/modprobe.d/blacklist-pn533_usb.conf"
UDEV_RULE_FILE="/etc/udev/rules.d/99-acr122u-power.rules"
UDEV_RULE='ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="072f", ATTR{idProduct}=="2200", TEST=="power/control", ATTR{power/control}="on"'

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
  command -v "$1" >/dev/null 2>&1 || {
    fail "Missing command: $1"
    exit 2
  }
}

run_sudo() {
  sudo "$@"
}

find_device_path() {
  local d vendor product
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" ]] || continue
    vendor=$(cat "$d/idVendor" 2>/dev/null || true)
    product=$(cat "$d/idProduct" 2>/dev/null || true)
    if [[ "$vendor" == "$VID" && "$product" == "$PID" ]]; then
      printf "%s\n" "$d"
      return 0
    fi
  done
  return 1
}

find_pn533_iface() {
  local iface
  if [[ ! -d /sys/bus/usb/drivers/pn533_usb ]]; then
    return 1
  fi

  while IFS= read -r iface; do
    [[ -n "$iface" ]] || continue
    printf "%s\n" "$iface"
    return 0
  done < <(for d in /sys/bus/usb/drivers/pn533_usb/*:*; do [[ -L "$d" ]] && basename "$d"; done 2>/dev/null)

  return 1
}

printf "\nACR122U Setup Installer\n"
printf "======================\n\n"

for cmd in sudo apt systemctl modprobe udevadm lsusb tee; do
  need_cmd "$cmd"
done

info "Installing required packages..."
run_sudo apt update
run_sudo apt install -y usbutils pcscd pcsc-tools libccid
pass "Required packages are installed."

info "Writing pn533 blacklist..."
printf "%s\n" "blacklist pn533_usb" | run_sudo tee "$BLACKLIST_FILE" >/dev/null
pass "Blacklist written to $BLACKLIST_FILE"

info "Writing udev rule for USB power/control=on..."
printf "%s\n" "$UDEV_RULE" | run_sudo tee "$UDEV_RULE_FILE" >/dev/null
pass "udev rule written to $UDEV_RULE_FILE"

info "Reloading udev rules..."
run_sudo udevadm control --reload-rules
run_sudo udevadm trigger
pass "udev rules reloaded."

if lsusb | grep -qi "${VID}:${PID}"; then
  pass "Reader ${VID}:${PID} is currently connected."
else
  warn "Reader ${VID}:${PID} is not currently connected. You can plug it in after setup."
fi

info "Stopping pcscd before driver changes..."
run_sudo systemctl stop pcscd pcscd.socket || true

info "Removing conflicting NFC kernel modules if loaded..."
run_sudo modprobe -r pn533_usb pn533 nfc || true
pass "Kernel module cleanup attempted."

DEV="$(find_device_path || true)"
if [[ -n "$DEV" ]]; then
  info "Found device path: $DEV"

  IFACE="$(find_pn533_iface || true)"
  if [[ -n "$IFACE" ]]; then
    info "Unbinding device from pn533_usb: $IFACE"
    printf "%s" "$IFACE" | run_sudo tee /sys/bus/usb/drivers/pn533_usb/unbind >/dev/null
    pass "pn533_usb unbind completed."
  fi

  if [[ -f "$DEV/authorized" ]]; then
    info "Reauthorizing USB device..."
    printf "0\n" | run_sudo tee "$DEV/authorized" >/dev/null
    printf "1\n" | run_sudo tee "$DEV/authorized" >/dev/null
    pass "USB device reauthorized."
  fi

  if [[ -f "$DEV/power/control" ]]; then
    info "Setting USB power/control to on..."
    printf "on\n" | run_sudo tee "$DEV/power/control" >/dev/null
    pass "USB power/control forced to on."
  fi
else
  warn "No live sysfs path found for the reader. Runtime USB fixes were skipped."
fi

info "Starting pcscd socket..."
run_sudo systemctl start pcscd.socket
pass "pcscd.socket started."

printf "\nNext steps\n"
printf "%s\n" "----------"
printf "1. Plug the reader directly into a laptop USB port.\n"
printf "2. Run ./nfc_reader_healthcheck.sh\n"
printf "3. If needed, test manually with: pcsc_scan\n"
printf "4. Reboot once to verify the persistent setup.\n"

if [[ -x ./nfc_reader_healthcheck.sh ]]; then
  printf "\nRunning local health check...\n\n"
  ./nfc_reader_healthcheck.sh || true
else
  warn "Health check script not found or not executable in current directory."
fi
