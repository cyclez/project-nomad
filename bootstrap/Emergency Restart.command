#!/usr/bin/env bash
#
# Double-click this file on macOS to restart the emergency daemon.
# Use this only if the phone has rebooted and did not come back by itself
# after about 2 minutes.
#

cd "$(dirname "$0")"

echo ""
echo "  Restarting emergency daemon (fallback mode)..."
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
