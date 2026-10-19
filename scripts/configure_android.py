from pathlib import Path
import re
manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
text = re.sub(r'android:label="[^"]*"', 'android:label="Домашка"', text)
manifest.write_text(text, encoding='utf-8')
print('Configured Android package and network permission')