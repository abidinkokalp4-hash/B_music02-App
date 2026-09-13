import importlib.util
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

spec = importlib.util.spec_from_file_location('configure', Path(__file__).resolve().parents[1] / 'tool/configure_android.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AndroidConfigurationTest(unittest.TestCase):
    def test_activity_name_does_not_hide_missing_service_and_repeat_is_safe(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AndroidManifest.xml'
            path.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <application><activity android:name="com.ryanheise.audioservice.AudioServiceActivity">
                <intent-filter><action android:name="android.intent.action.MAIN" /></intent-filter>
              </activity></application></manifest>''')
            module.configure_manifest(path)
            first = path.read_text()
            module.configure_manifest(path)
            self.assertEqual(first, path.read_text())
            root = ET.parse(path).getroot()
            app = root.find('application')
            self.assertEqual(len(app.findall('service')), 1)
            self.assertEqual(len(app.findall('receiver')), 1)
            self.assertEqual(app.find('service').get(module.A + 'foregroundServiceType'), 'mediaPlayback')
            legacy = next(e for e in root.findall('uses-permission') if e.get(module.A + 'name').endswith('READ_EXTERNAL_STORAGE'))
            self.assertEqual(legacy.get(module.A + 'maxSdkVersion'), '32')

    def test_legacy_plugin_namespace_migration(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            android = root / 'plugin/android'
            (android / 'src/main').mkdir(parents=True)
            (android / 'build.gradle').write_text('android {\n compileSdkVersion 33\n}')
            (android / 'src/main/AndroidManifest.xml').write_text('<manifest package="com.example.audio"/>')
            config = root / 'package_config.json'
            config.write_text(json.dumps({'packages': [{'name': 'on_audio_query_android', 'rootUri': 'plugin/'}]}))
            module.patch_audio_query(config)
            module.patch_audio_query(config)
            self.assertEqual((android / 'build.gradle').read_text().count('namespace "com.example.audio"'), 1)
            self.assertNotIn('package', ET.parse(android / 'src/main/AndroidManifest.xml').getroot().attrib)
