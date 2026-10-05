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
              <uses-permission android:name="android.permission.INTERNET" />
              <application><activity android:name="com.ryanheise.audioservice.AudioServiceActivity">
                <intent-filter><action android:name="android.intent.action.MAIN" /></intent-filter>
              </activity></application></manifest>''')
            module.configure_manifest(path)
            first = path.read_text()
            module.configure_manifest(path)
            self.assertEqual(first, path.read_text())
            root = ET.parse(path).getroot()
            internet = [e for e in root.findall('uses-permission') if e.get(module.A + 'name') == 'android.permission.INTERNET']
            self.assertEqual(len(internet), 1)
            self.assertIsNone(internet[0].get('{http://schemas.android.com/tools}node'))
            app = root.find('application')
            renderer = next(x for x in app.findall('meta-data') if x.get(module.A + 'name') == 'io.flutter.embedding.android.EnableImpeller')
            self.assertEqual(renderer.get(module.A + 'value'), 'false')
            self.assertEqual(len(app.findall('service')), 2)
            self.assertEqual(len(app.findall('receiver')), 2)
            widget = next(x for x in app.findall('receiver') if x.get(module.A + 'name').endswith('MusicWidgetProvider'))
            self.assertEqual(widget.get(module.A + 'exported'), 'false')
            self.assertTrue(module.has_action(widget, 'android.appwidget.action.APPWIDGET_UPDATE'))
            self.assertEqual(widget.find('meta-data').get(module.A + 'resource'), '@xml/music_widget_info')
            aliases = app.findall('activity-alias')
            self.assertEqual(len(aliases), 3)
            self.assertEqual(sum(x.get(module.A + 'enabled') == 'true' for x in aliases), 1)
            self.assertTrue(all(x.get(module.A + 'targetActivity') == 'com.example.b_music02.MainActivity' for x in aliases))
            self.assertTrue(all(module.has_action(x, 'android.intent.action.MAIN') for x in aliases))
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
            self.assertIn('compileSdkVersion 36', (android / 'build.gradle').read_text())
            self.assertIn('targetCompatibility JavaVersion.VERSION_17', (android / 'build.gradle').read_text())
            self.assertIn('jvmTarget = "17"', (android / 'build.gradle').read_text())
            self.assertEqual((android / 'build.gradle').read_text().count('// b_music02 JVM compatibility'), 1)
            self.assertNotIn('package', ET.parse(android / 'src/main/AndroidManifest.xml').getroot().attrib)
