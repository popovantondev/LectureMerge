#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache Sources/Localization.swift Sources/Core.swift Sources/Audio.swift Sources/Project.swift Tests/Integration.swift -o build/integration-tests
build/integration-tests "$@"

if [ "$#" -eq 0 ]; then bash Scripts/test-v2.sh; fi
