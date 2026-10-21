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

# Transitive ONNX and PDF libraries may still package 32-bit/x86 variants.
# Keep only Android ARM64 to avoid bloated APK and unsupported plugin ABI.
if app_gradle.exists():
    gradle = app_gradle.read_text(encoding='utf-8')
    guard = 'excludes += setOf("lib/armeabi-v7a/**"'
    if guard not in gradle:
        insertion = '''
        packaging {
            jniLibs {
                excludes += setOf(
                    "lib/armeabi-v7a/**",
                    "lib/x86/**",
                    "lib/x86_64/**",
                )
            }
        }
'''
        gradle = gradle.replace('defaultConfig {', insertion + '\n    defaultConfig {', 1)
        app_gradle.write_text(gradle, encoding='utf-8')
