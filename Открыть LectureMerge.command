#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
TASK_VERSION="$(python3 "$TASK_ROOT/Scripts/release_support.py" version)"
TASK_APP="$TASK_ROOT/dist/v$TASK_VERSION/Сборка лекций 2.app"
if [ ! -d "$TASK_APP" ]; then
    echo "Сборка v$TASK_VERSION ещё не создана. Готовые старые версии находятся в dist и releases."
    exit 1
fi
open "$TASK_APP"
