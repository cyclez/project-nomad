#!/usr/bin/env bash
#
# Removes the macOS quarantine flag from this folder.
# Use this if Finder says "unidentified developer".
#
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xattr >/dev/null 2>&1; then
  echo ""
  echo "  This Mac does not have the 'xattr' command."
  echo "  Run this in Terminal instead:"
  echo ""
  echo "    xattr -dr com.apple.quarantine \"$(pwd)\""
  echo ""
  read -rp "  Press Enter to close."
  exit 1
fi

echo ""
echo "  Removing the macOS security block from:"
echo "  $(pwd)"
echo ""

xattr -dr com.apple.quarantine .

echo "  Done. This folder is unblocked."
echo ""
echo "  Next step:"
echo "  Double-click Emergency Install.command"
echo ""
read -rp "  Press Enter to close."
