#!/usr/bin/env python3
"""Read a dotted field from a JSON file. Replaces the node one-liner."""
import json, sys
if len(sys.argv) < 3:
    sys.exit(1)
with open(sys.argv[1]) as f:
    obj = json.load(f)
for key in sys.argv[2].split("."):
    obj = obj[key] if isinstance(obj, dict) else obj[int(key)]
print(obj, end="")
