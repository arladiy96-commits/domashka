"""Bundle official PP-OCRv5 Cyrillic ONNX models during CI, never on device.

Pin model digests so a changed upstream download fails safely.
The recognition dictionary MUST come from that same model's inference.yml.
"""
from pathlib import Path
import hashlib
import urllib.request
import time

ROOT = Path("assets/paddle_models")
ROOT.mkdir(parents=True, exist_ok=True)
REPOS = {
    "det.onnx": (
        "PP-OCRv5_mobile_det_onnx", "inference.onnx",
        "a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d",
    ),
    "rec.onnx": (
        "cyrillic_PP-OCRv5_mobile_rec_onnx", "inference.onnx",
        "5371ee1ddaa7983cc62d0818d99e982b6804638c85e4f960d59a574094e172e5",
    ),
}

def download(repo, path):
    url = "https://huggingface.co/PaddlePaddle/" + repo + "/resolve/main/" + path
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Domashka-CI/1.0"})
            with urllib.request.urlopen(req, timeout=120) as response:
                return response.read()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))

for filename, (repo, name, expected) in REPOS.items():
    dest = ROOT / filename
    if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == expected:
        continue
    data = download(repo, name)
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected:
        raise RuntimeError(f"{filename}: model checksum mismatch: {digest}")
    dest.write_bytes(data)
    print(f"Verified {filename}, {len(data)} bytes")

# Read the YAML as YAML; naive stripping corrupts quoted punctuation and spaces.
import yaml
config = yaml.safe_load(download("cyrillic_PP-OCRv5_mobile_rec_onnx", "inference.yml"))
characters = config["PostProcess"]["character_dict"]
if not isinstance(characters, list) or len(characters) < 100:
    raise RuntimeError("Cyrillic OCR character dictionary is missing")
if not all(isinstance(char, str) for char in characters):
    raise RuntimeError("OCR dictionary contains invalid characters")
(ROOT / "dict.txt").write_text("\n".join(characters) + "\n", encoding="utf-8")
print(f"Packaged {len(characters)} model dictionary entries")
