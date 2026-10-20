#!/usr/bin/env python3
"""Bundle official Tesseract language files into the APK at build time.

No traineddata download happens on the user's phone.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import os
import tempfile

TARGET = Path("assets/tessdata")
BASE = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/"

def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    for language in ("rus", "eng"):
        destination = TARGET / (language + ".traineddata")
        if destination.exists() and destination.stat().st_size > 100_000:
            print("Already present:", destination, destination.stat().st_size)
            continue
        print("Bundling OCR model:", language, flush=True)
        request = Request(BASE + language + ".traineddata", headers={
            "User-Agent": "domashka-android-build/1.0",
        })
        descriptor, temporary = tempfile.mkstemp(dir=TARGET, prefix=".download_")
        try:
            with os.fdopen(descriptor, "wb") as output, urlopen(request, timeout=120) as response:
                while True:
                    chunk = response.read(1024 * 512)
                    if not chunk:
                        break
                    output.write(chunk)
            if Path(temporary).stat().st_size < 100_000:
                raise RuntimeError("OCR model is unexpectedly small: " + language)
            os.replace(temporary, destination)
            print("Downloaded", destination, destination.stat().st_size, "bytes", flush=True)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

if __name__ == "__main__":
    main()
