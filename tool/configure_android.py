"""Apply Android media setup identically for local builds and CI."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
ANDROID = 'http://schemas.android.com/apk/res/android'
A = '{' + ANDROID + '}'
ET.register_namespace('android', ANDROID)


def configure_manifest(path: Path) -> None:
    tree = ET.parse(path)
    root = tree.getroot()
    permissions = {
        'INTERNET': None, 'WAKE_LOCK': None, 'FOREGROUND_SERVICE': None,
        'FOREGROUND_SERVICE_MEDIA_PLAYBACK': None, 'READ_MEDIA_AUDIO': None,
        'READ_EXTERNAL_STORAGE': '32', 'POST_NOTIFICATIONS': None,
    }
    for name, max_sdk in permissions.items():
        full_name = 'android.permission.' + name
        element = next((e for e in root.findall('uses-permission') if e.get(A + 'name') == full_name), None)
        if element is None:
            element = ET.SubElement(root, 'uses-permission', {A + 'name': full_name})
        if max_sdk:
            element.set(A + 'maxSdkVersion', max_sdk)
    app = root.find('application')
    if app is None:
        raise ValueError('Android application element missing')
    app.set(A + 'label', 'B_music02')
    # Match XML elements exactly: AudioServiceActivity is not AudioService.
    for activity in app.findall('activity'):
        if any(a.get(A + 'name') == 'android.intent.action.MAIN' for a in activity.findall('intent-filter/action')):
            activity.set(A + 'name', 'com.ryanheise.audioservice.AudioServiceActivity')
    for tag, name, action in [
        ('service', 'com.ryanheise.audioservice.AudioService', 'android.media.browse.MediaBrowserService'),
        ('receiver', 'com.ryanheise.audioservice.MediaButtonReceiver', 'android.intent.action.MEDIA_BUTTON'),
    ]:
        element = next((e for e in app.findall(tag) if e.get(A + 'name') == name), None)
        if element is None:
            element = ET.SubElement(app, tag, {A + 'name': name})
        element.set(A + 'exported', 'true')
        if tag == 'service':
            element.set(A + 'foregroundServiceType', 'mediaPlayback')
        if not any(e.get(A + 'name') == action for e in element.findall('intent-filter/action')):
            intent = ET.SubElement(element, 'intent-filter')
            ET.SubElement(intent, 'action', {A + 'name': action})
    ET.indent(tree, space='    ')
    tree.write(path, encoding='unicode')


def patch_audio_query(config_path: Path) -> None:
    # The upstream 1.1.0 Android implementation predates AGP 8 namespaces.
    config = json.loads(config_path.read_text())
    package = next(p for p in config['packages'] if p['name'] == 'on_audio_query_android')
    uri = package['rootUri']
    root = Path(unquote(urlparse(uri).path)) if uri.startswith('file:') else (config_path.parent / unquote(uri)).resolve()
    gradle = root / 'android/build.gradle'
    manifest = root / 'android/src/main/AndroidManifest.xml'
    tree = ET.parse(manifest)
    package_name = tree.getroot().attrib.pop('package', None)
    text = gradle.read_text()
    if not re.search(r'\bnamespace\s*[= ]', text):
        if not package_name:
            raise ValueError('Cannot determine on_audio_query_android namespace')
        text = re.sub(r'android\s*\{', 'android {\n    namespace "' + package_name + '"', text, count=1)
    text = re.sub(r'compileSdkVersion\s+\d+', 'compileSdkVersion 36', text)
    # Modern Flutter uses Java 17, while this legacy library defaults to Java 11.
    # Configure both compilers rather than disabling Kotlin's compatibility gate.
    marker = '// b_music02 JVM compatibility'
    if marker not in text:
        text += '\n' + marker + '\n' + 'android {\n    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_17\n        targetCompatibility JavaVersion.VERSION_17\n    }\n    kotlinOptions {\n        jvmTarget = "17"\n    }\n}\n'
    # AGP 8 rejects a library manifest package attribute even with namespace set.
    gradle.write_text(text)
    tree.write(manifest, encoding='unicode')


def main() -> None:
    configure_manifest(ROOT / 'android/app/src/main/AndroidManifest.xml')
    drawable = ROOT / 'android/app/src/main/res/drawable'
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / 'ic_stat_music.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:pathData="M12,3v10.55A4,4 0,1 0,14 17V7h4V3z" />
</vector>''')
    # The notification icon is resolved by name from Dart. Keep it through
    # Android release resource shrinking even though no native XML references it.
    raw = ROOT / 'android/app/src/main/res/raw'
    raw.mkdir(parents=True, exist_ok=True)
    (raw / 'keep.xml').write_text('<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_music" />')
    patch_audio_query(ROOT / '.dart_tool/package_config.json')
    print('Android permissions, media service, receiver and audio-query namespace configured.')


if __name__ == '__main__':
    main()
