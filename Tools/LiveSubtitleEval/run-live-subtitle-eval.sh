#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMAND="${1:---self-test}"

case "$COMMAND" in
  --list)
    export ECHOV_LIVE_SUBTITLE_EVAL_COMMAND=list
    ;;
  --dry-run)
    export ECHOV_LIVE_SUBTITLE_EVAL_COMMAND=dry-run
    ;;
  --self-test)
    export ECHOV_LIVE_SUBTITLE_EVAL_COMMAND=self-test
    ;;
  --run)
    export ECHOV_LIVE_SUBTITLE_EVAL_COMMAND=run
    if [[ "${2:-}" != "" ]]; then
      export ECHOV_LIVE_SUBTITLE_EVAL_SCENARIO="$2"
    fi
    if [[ "${3:-}" != "" ]]; then
      export ECHOV_LIVE_SUBTITLE_EVAL_PRESET="$3"
    fi
    ;;
  --verify-latest)
    export ECHOV_LIVE_SUBTITLE_EVAL_COMMAND=verify-latest
    ;;
  *)
    echo "Usage: $0 --list|--dry-run|--self-test|--run [scenario-id]|--verify-latest" >&2
    exit 2
    ;;
esac

cd "$ROOT"
mkdir -p "$ROOT/.build-test/clang-module-cache" "$ROOT/.build-test/swiftpm-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build-test/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build-test/swiftpm-module-cache"
swift test --scratch-path "$ROOT/.build-test" --filter LiveSubtitleEvaluationTests/testHarnessCommand
