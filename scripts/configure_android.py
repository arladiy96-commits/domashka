from pathlib import Path
import re
manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
text = re.sub(r'android:label="[^"]*"', 'android:label="Домашка"', text)
manifest.write_text(text, encoding='utf-8')
print('Configured Android package and network permission')
# PP-OCRv5 ONNX plugin currently has native binaries only for arm64-v8a.
app_gradle = Path('android/app/build.gradle.kts')
if app_gradle.exists():
    gradle = app_gradle.read_text(encoding='utf-8')
    needle = 'defaultConfig {'
    if 'abiFilters += "arm64-v8a"' not in gradle and needle in gradle:
        gradle = gradle.replace(needle, needle + '\n        ndk { abiFilters += "arm64-v8a" }', 1)
        app_gradle.write_text(gradle, encoding='utf-8')
