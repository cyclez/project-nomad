#!/usr/bin/env bash
#
# Double-click to COMPLETELY remove emergency-nomad from the phone.
# Removes runtime, data, AND the APK. Nothing left on device.
#

cd "$(dirname "$0")"

bash ./uninstall.sh --full

echo ""
read -rp "  Press Enter to close."
