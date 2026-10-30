#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

xcrun swiftc clipaste/Views/NativeTextView.swift \
  scripts/NativeTextViewLayoutTests.swift -o "$test_dir/text-preview"

# 布局死循环会阻塞主线程，使用独立进程超时保护验证脚本。
python3 - "$test_dir/text-preview" <<'PY'
import subprocess
import sys

try:
    result = subprocess.run([sys.argv[1]], timeout=30)
except subprocess.TimeoutExpired:
    print("文本预览验证超时：可能出现布局死循环", file=sys.stderr)
    sys.exit(1)
sys.exit(0 if result.returncode == 0 else 1)
PY
