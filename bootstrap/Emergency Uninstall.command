#!/usr/bin/env bash
#
# Double-click to remove emergency-nomad runtime from the phone.
# Keeps the APK installed for fast reinstall.
# For full removal (including APK): use "Emergency Uninstall (full)"
#

cd "$(dirname "$0")"

bash ./uninstall.sh

echo ""
read -rp "  Press Enter to close."
