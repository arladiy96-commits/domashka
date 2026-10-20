#!/usr/bin/env python3
"""Compatibility patch for the upstream tesseract_ocr 0.5.0 Android Gradle.

This modifies only the downloaded local pub cache, not the app sources.
The plugin still refers to removed Gradle jcenter() repositories.
"""
from pathlib import Path
import os

VERSION = "0.5.0"
pub_cache = Path(os.environ.get("PUB_CACHE", str(Path.home() / ".pub-cache")))
target = pub_cache / "hosted" / "pub.dev" / ("tesseract_ocr-" + VERSION) / "android" / "build.gradle"
if not target.exists():
    raise SystemExit("Missing Tesseract Android Gradle file: " + str(target))
text = target.read_text(encoding="utf-8")
if "jcenter()" not in text:
    print("Tesseract plugin already uses supported Maven repositories.")
else:
    text = text.replace("jcenter()", "mavenCentral()")
    target.write_text(text, encoding="utf-8")
    print("Patched removed jcenter() calls:", target)

# Gradle 9/modern Kotlin defaults to JVM 17, while the plugin's Java
# compile task defaults to 11. Both compilation targets must match.
text = target.read_text(encoding="utf-8")
if "sourceCompatibility JavaVersion.VERSION_17" not in text:
    text += "\nandroid {\n  compileOptions {\n    sourceCompatibility JavaVersion.VERSION_17\n    targetCompatibility JavaVersion.VERSION_17\n  }\n}\n"
    target.write_text(text, encoding="utf-8")
    print("Aligned OCR plugin Java target with Kotlin JVM 17:", target)

# Upstream 0.5.0 ships two Flutter plugin classes with the same
# package and name: one real Java OCR implementation and a nonfunctional
# Kotlin scaffold. Remove only the scaffold during the CI build.
scaffold = target.parent / "src" / "main" / "kotlin" / "io" / "paratoner" / "tesseract_ocr" / "TesseractOcrPlugin.kt"
if scaffold.exists():
    contents = scaffold.read_text(encoding="utf-8")
    if "getPlatformVersion" not in contents or "extractText" in contents:
        raise SystemExit("Unexpected Kotlin plugin implementation; refusing to delete " + str(scaffold))
    scaffold.unlink()
    print("Removed duplicate nonfunctional Kotlin plugin scaffold:", scaffold)
