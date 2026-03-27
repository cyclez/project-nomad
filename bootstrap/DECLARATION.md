# Emergency Bootstrap — Declaration of Intent

## What this software does

This tool pushes an emergency information runtime to an Android device
connected via USB. One command, one cable, one ZIP.

Actions performed:

1. Detects a connected Android device via ADB (Android Debug Bridge).
2. Verifies device compatibility (Android version, processor architecture).
3. Extracts and verifies all files from the bundle on the host computer.
4. Pushes the pre-assembled runtime to the device via USB.
5. Installs the runtime into device-local storage.
6. Launches a local daemon bound to 127.0.0.1:1234 (loopback only).
7. Opens a browser on the device (or forwards the port to the computer
   if the device screen is broken).

After installation the daemon keeps running when the USB cable is
disconnected. The device works standalone, offline, with no network.

## What this software does NOT do

- Does not root the device.
- Does not install an APK or modify system settings.
- Does not modify the bootloader, recovery, or system partition.
- Does not install system services that survive a factory reset.
- Does not transmit data from the device to the host or to any network.
- Does not bypass device encryption or lock screen.
- Does not fetch anything from the network during install.
- Does not require Google Play, Docker, or any external service.

## What this software uses on the device

- Storage space in /data/local/tmp/emergency-nomad/ (size depends on bundle).
- One background process (the daemon) that listens on 127.0.0.1:1234.
- The daemon is NOT reachable from other devices on any network.

## Known limitation

If the phone restarts (reboot, battery dies), the daemon stops.
Reconnect the USB cable and run the restart command to relaunch it.
The installed files and data are NOT lost — only the daemon needs restarting.

## Network policy

The runtime starts with network policy OFF.
The device will not attempt any network activity after installation.
One-shot sync can be armed explicitly by the operator after install.

## Who should use this

This is experimental emergency software for dedicated development
and testing devices ("dev-burner" phones).

It is NOT recommended for use on a personal daily-driver phone.
We do not recommend anyone to install this software.

## Preconditions

- USB debugging enabled on the Android device.
- "Always allow from this computer" authorized on the device
  (important: do this BEFORE an emergency, while the screen works).
- ADB available on the host computer.
- USB data cable (not charge-only).

## Consent

The push script displays this declaration and requires explicit
confirmation before performing any action on the connected device.
