# PP-OCRv5 Cyrillic on-device preview

This branch adds a second independent offline recognizer (the old Tesseract
remains selectable for an A/B comparison). The app ships the ONNX models,
so the phone does not download anything and does not upload images to a service.

* Official PP-OCRv5 mobile detection: PaddlePaddle/PP-OCRv5_mobile_det_onnx.
* Official Cyrillic PP-OCRv5 mobile recognition:
  PaddlePaddle/cyrillic_PP-OCRv5_mobile_rec_onnx.
* Inference plugin is pinned to mencomao/flutter-paddle-ocr commit
  3bfac2e79a55950abb2519ad1e9ee637bef74bc1, Apache-2.0.
* The build fetches official ONNX assets with SHA-256 validation and extracts
  the matching recognition dictionary from inference.yml using PyYAML.
* Supported native architecture: arm64-v8a; phones with other ABIs will not
  support the ONNX plugin. Retain an untouched v0.1.33 APK for rollback.
* OCR is not image understanding. Printed tables and diagrams must be checked
  against the photograph before using a computed answer.

## Benchmarks to run on real school cards

For each photo compare PP-OCRv5, Tesseract, and Gemini (when explicitly enabled).
Record: exact matches of digits, equals/inequality, column boundaries, missing
lines, recognition time and any undetected diagrams.

CI unit tests cover polygon reading order and column segmentation. They do NOT
certify native recognition quality or a perfect answer. Run the preview APK
on a physical Android ARM64 device to assess actual accuracy.
