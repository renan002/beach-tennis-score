#!/bin/bash
# PROTOTYPE — throwaway. One command to drive the #102 Health toggle state model.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
out="$(mktemp -d)/health-toggle"
swiftc -O -o "$out" "$dir/HealthToggleDisplay.swift" "$dir/main.swift"
exec "$out"
