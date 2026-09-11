from __future__ import annotations
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        temp_project = Path(tmp) / 'b_music02_native'
        subprocess.run([
            'flutter', 'create',
            '--platforms=android,ios',
            '--org', 'com.bmusic02',
            '--project-name', 'b_music02',
            str(temp_project),
        ], check=True)

        for platform in ('android', 'ios'):
            destination = ROOT / platform
            if destination.exists():
                shutil.rmtree(destination)
            shutil.copytree(temp_project / platform, destination)

    android_gradle = ROOT / 'android/app/build.gradle.kts'
    if android_gradle.exists():
        text = android_gradle.read_text(encoding='utf-8')
        text = re.sub(r'namespace = "[^"]+"', 'namespace = "com.bmusic02.app"', text)
        text = re.sub(r'applicationId = "[^"]+"', 'applicationId = "com.bmusic02.app"', text)
        android_gradle.write_text(text, encoding='utf-8')

    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if manifest.exists():
        text = manifest.read_text(encoding='utf-8')
        permission = '<uses-permission android:name="android.permission.INTERNET" />'
        if permission not in text:
            text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission)
        manifest.write_text(text, encoding='utf-8')

    kotlin_root = ROOT / 'android/app/src/main/kotlin'
    source = next(kotlin_root.rglob('MainActivity.kt'), None) if kotlin_root.exists() else None
    if source:
        new_dir = kotlin_root / 'com/bmusic02/app'
        new_dir.mkdir(parents=True, exist_ok=True)
        text = source.read_text(encoding='utf-8')
        text = re.sub(r'^package\s+[^\n]+', 'package com.bmusic02.app', text, flags=re.MULTILINE)
        target = new_dir / 'MainActivity.kt'
        target.write_text(text, encoding='utf-8')
        if source.resolve() != target.resolve():
            source.unlink()

    plist_path = ROOT / 'ios/Runner/Info.plist'
    if plist_path.exists():
        with plist_path.open('rb') as f:
            data = plistlib.load(f)
        data['NSPhotoLibraryUsageDescription'] = 'Profil fotoğrafınızı seçebilmek için fotoğraf arşivinize erişim gerekir.'
        with plist_path.open('wb') as f:
            plistlib.dump(data, f, sort_keys=False)

    pbx = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    if pbx.exists():
        text = pbx.read_text(encoding='utf-8')
        text = re.sub(
            r'PRODUCT_BUNDLE_IDENTIFIER = (com\.bmusic02\.[^;]+);',
            lambda m: 'PRODUCT_BUNDLE_IDENTIFIER = com.bmusic02.app.RunnerTests;'
            if 'RunnerTests' in m.group(1)
            else 'PRODUCT_BUNDLE_IDENTIFIER = com.bmusic02.app;',
            text,
        )
        pbx.write_text(text, encoding='utf-8')

    print('Android/iOS platform files prepared. Bundle/application id: com.bmusic02.app')


if __name__ == '__main__':
    main()
