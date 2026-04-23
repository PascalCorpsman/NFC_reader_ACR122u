# NFC Reader

Setup notes for the ACR122U NFC card reader on Linux.

1. Install dependencies

	sudo apt update
	sudo apt install pcscd pcsc-tools libccid

2. Verify the reader is visible on USB

	lsusb | grep 072f:2200

3. If pcsc_scan does not detect the reader, check whether Linux bound it to pn533_usb

	lsusb -t | grep -E "072f:2200|pn533_usb|SmartCard"

4. Unbind dynamically from pn533_usb (do not use a hard-coded value like 3-1:1.0)

	IFACE=$(for d in /sys/bus/usb/drivers/pn533_usb/*:*; do [ -L "$d" ] && basename "$d"; done | head -n1)
	echo "$IFACE"
	echo -n "$IFACE" | sudo tee /sys/bus/usb/drivers/pn533_usb/unbind

5. Restart pcscd and test

	sudo systemctl restart pcscd
	pcsc_scan

Expected: pcsc_scan should list ACS ACR122U PICC Interface.

Optional persistent fix
If pn533_usb keeps grabbing the device after reboot/replug and you only need PC/SC mode:

	echo "blacklist pn533_usb" | sudo tee /etc/modprobe.d/blacklist-pn533_usb.conf
	sudo modprobe -r pn533_usb pn533 nfc
	sudo systemctl restart pcscd

Troubleshooting

- If IFACE is empty, unplug and replug the reader, then run step 4 again.
- Your interface path can change, for example 1-1.4.3.1.4:1.0, so hard-coded paths are brittle.
- If pcscd logs show LIBUSB_ERROR_BUSY, another driver still owns the interface.
- If pn533_usb is already blocked but pcscd shows LIBUSB_ERROR_TIMEOUT after reboot, disable USB autosuspend for the reader.

Timeout fix after reboot (ACR122U)

Temporary (until next reboot):

	echo on | sudo tee /sys/bus/usb/devices/1-1.1/power/control
	sudo systemctl restart pcscd
	pcsc_scan

Persistent via udev rule:

	echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="072f", ATTR{idProduct}=="2200", TEST=="power/control", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/99-acr122u-power.rules
	sudo udevadm control --reload-rules
	sudo udevadm trigger

Then unplug/replug the reader once and run:

	pcsc_scan

If it still fails (reader beeps, but pcsc_scan shows no reader)

This usually means USB communication timed out and the reader needs a clean re-enumeration.

1. Find the current USB sysfs path

	DEV=$(for d in /sys/bus/usb/devices/*; do [ -f "$d/idVendor" ] || continue; [ "$(cat "$d/idVendor" 2>/dev/null)" = "072f" ] && [ "$(cat "$d/idProduct" 2>/dev/null)" = "2200" ] && echo "$d"; done | head -n1)
	echo "$DEV"

2. Restart stack and force USB re-enumeration

	sudo systemctl stop pcscd pcscd.socket
	echo 0 | sudo tee "$DEV/authorized"
	echo 1 | sudo tee "$DEV/authorized"
	echo on | sudo tee "$DEV/power/control"
	sudo systemctl start pcscd.socket
	pcsc_scan

3. If it still times out, unplug the reader for 5 seconds and reconnect it to a direct USB port (avoid passive hubs), then run pcsc_scan again.

Known good setup

- On this machine, ACR122U works reliably on a direct laptop USB port.
- Through a hub, the reader may be visible in lsusb but still fail in pcscd with LIBUSB_ERROR_TIMEOUT.

Health check script

Run the local diagnostic script:

	./nfc_reader_healthcheck.sh

If needed, make it executable first:

	chmod +x ./nfc_reader_healthcheck.sh

Reboot test flow:

1. Reboot machine.
2. Plug reader directly into laptop USB port.
3. Run ./nfc_reader_healthcheck.sh.
4. If pcsc_scan is not detected, follow the script's suggested fixes.

Setup installer script

Use the separate setup script to apply the persistent fixes automatically:

	./nfc_reader_setup.sh

What it does:

- Installs required packages.
- Writes the pn533 blacklist file.
- Writes the udev rule for power/control=on.
- Reloads udev rules.
- Tries to unload conflicting NFC kernel modules.
- If the reader is connected, it also applies the runtime USB recovery steps.
- Starts pcscd.socket and runs the local health check at the end.

Recommended usage:

1. Plug the reader directly into a laptop USB port.
2. Run ./nfc_reader_setup.sh.
3. Reboot once.
4. Run ./nfc_reader_healthcheck.sh.
