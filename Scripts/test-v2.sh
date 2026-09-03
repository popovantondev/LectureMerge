#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache Sources/Core.swift Sources/Audio.swift Sources/Project.swift Tests/V2.swift -o build/v2-tests
build/v2-tests
