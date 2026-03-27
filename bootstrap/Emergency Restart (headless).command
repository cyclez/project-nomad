#!/usr/bin/env bash
#
# Double-click this file on macOS to restart the emergency daemon
# in headless mode (for phones with broken screens).
# The browser opens on this computer. Keep the cable connected.
#

cd "$(dirname "$0")"

echo ""
echo "  Restarting emergency daemon (headless — broken screen mode)..."
echo ""

bash ./usb-push.sh --restart --headless

EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  Done. Keep the cable connected."
else
  echo "  Something went wrong. Read the messages above."
fi

echo ""
read -rp "  Press Enter to close."
