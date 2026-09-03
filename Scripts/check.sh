#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
python3 Scripts/check-project.py
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -typecheck -target arm64-apple-macosx14.0 \
    -module-cache-path build/module-cache \
    -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers Sources/*.swift
echo "Swift type check: OK"
