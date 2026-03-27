#!/usr/bin/env bash
#
# Double-click this file on macOS to install the emergency runtime.
# It opens Terminal and waits for you to connect the phone.
#
# Before using: place your bundle .zip file next to this file.
#

cd "$(dirname "$0")"

# Find the first .zip bundle in this directory
BUNDLE=$(ls -1 *.zip 2>/dev/null | head -1)

if [ -z "$BUNDLE" ]; then
  echo ""
  echo "  No .zip bundle found."
  echo ""
  echo "  Place your emergency bootstrap .zip file"
  echo "  in the same folder as this icon, then double-click again."
  echo ""
  read -rp "  Press Enter to close."
  exit 1
fi

bash ./emergency-watch.sh "$BUNDLE"

EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  Done. You can close this window."
else
  echo "  Something went wrong. Read the messages above."
fi

echo ""
read -rp "  Press Enter to close."
