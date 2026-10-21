#!/usr/bin/env python3
"""Fix fatal Android crash in pinned flutter_paddle_ocr_v5 plugin.

Upstream issue #1: Kotlin Unit from the 'dispose' MethodChannel handler reaches
StandardMessageCodec, triggering IllegalArgumentException on the Android main
thread. Dart try/finally cannot catch this platform-process crash.
Patch only the exact pinned plugin copy in PUB_CACHE at build time, fail closed
if upstream changes unexpectedly, and assert the replacement was applied.
"""
import os
from pathlib import Path

pub_cache = Path(os.environ.get("PUB_CACHE", str(Path.home() / ".pub-cache")))
folder = pub_cache / "git"
paths = sorted(folder.glob(
    "flutter-paddle-ocr-*/android/src/main/kotlin/"
    "com/huyphan/flutter_paddle_ocr/FlutterPaddleOcrPlugin.kt"
))
if len(paths) != 1:
    raise SystemExit(
        f"Expected exactly one Flutter Paddle OCR plugin, got {len(paths)} "
        f"in {folder}: {paths}"
    )

path = paths[0]
source = path.read_text(encoding="utf-8")
old = '"dispose" -> runOnWorker(result) { handleDispose(call) }'
new = '"dispose" -> runOnWorker(result) { handleDispose(call); null }'
if old in source:
    assert source.count(old) == 1
    source = source.replace(old, new)
    path.write_text(source, encoding="utf-8")
    print("Patched fatal Kotlin Unit response in PaddleOCR dispose:", path)
elif new in source:
    print("PaddleOCR dispose already patched:", path)
else:
    raise SystemExit("Unexpected PaddleOCR implementation; refusing unsafe patch")

assert new in path.read_text(encoding="utf-8")
assert old not in path.read_text(encoding="utf-8")
print("PaddleOCR StandardMessageCodec dispose guard VERIFIED")
