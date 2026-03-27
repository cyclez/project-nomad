#!/usr/bin/env bash
#
# Double-click this file on macOS to restart the emergency daemon.
# Use this when the phone has rebooted and needs the daemon relaunched.
#

cd "$(dirname "$0")"

echo ""
echo "  Restarting emergency daemon..."
echo ""

bash ./usb-push.sh --restart

EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  Done. You can close this window."
else
  echo "  Something went wrong. Read the messages above."
fi

echo ""
read -rp "  Press Enter to close."
