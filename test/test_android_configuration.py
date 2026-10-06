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
            activity = app.find('activity')
            deep = next(x for x in activity.findall('meta-data') if x.get(module.A + 'name') == 'flutter_deeplinking_enabled')
            self.assertEqual(deep.get(module.A + 'value'), 'false')
            view = next(f for f in activity.findall('intent-filter') if any(x.get(module.A + 'name') == 'android.intent.action.VIEW' for x in f.findall('action')))
            self.assertEqual({d.get(module.A + 'mimeType') for d in view.findall('data') if d.get(module.A + 'mimeType')}, {'audio/*', 'video/*', 'application/ogg', 'application/x-matroska'})
            self.assertEqual({d.get(module.A + 'scheme') for d in view.findall('data') if d.get(module.A + 'scheme')}, {'content', 'file'})
            services = [x for x in app.findall('service') if x.get('{http://schemas.android.com/tools}node') != 'remove']
            self.assertEqual(len(services), 3)
            push = next(x for x in services if x.get(module.A + 'name') == 'com.example.b_music02.PushMessagingService')
            self.assertEqual(push.get(module.A + 'exported'), 'false')
            self.assertTrue(module.has_action(push, 'com.google.firebase.MESSAGING_EVENT'))
            removed = [x.get(module.A + 'name') for x in app.findall('service') if x.get('{http://schemas.android.com/tools}node') == 'remove']
            self.assertEqual(removed, ['io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService'])
            meta = {x.get(module.A + 'name'): x for x in app.findall('meta-data')}
            self.assertEqual(meta['com.google.firebase.messaging.default_notification_channel_id'].get(module.A + 'value'), 'announcements')
            self.assertEqual(meta['com.google.firebase.messaging.default_notification_icon'].get(module.A + 'resource'), '@drawable/ic_stat_music')
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

    def test_release_signing_uses_persistent_key_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            gradle = Path(directory) / 'build.gradle.kts'
            gradle.write_text('android {\n    defaultConfig {\n    }\n\n    buildTypes {\n        release {\n'
                              '            signingConfig = signingConfigs.getByName("debug")\n        }\n    }\n}\n')
            module.configure_signing(gradle)
            first = gradle.read_text()
            module.configure_signing(gradle)
            self.assertEqual(first, gradle.read_text())
            self.assertEqual(first.count('create("bmusicRelease")'), 1)
            self.assertIn('System.getenv("BMUSIC_KEYSTORE_PATH")', first)
            self.assertIn('signingConfigs.findByName("bmusicRelease") ?: signingConfigs.getByName("debug")', first)
            self.assertLess(first.index('signingConfigs {'), first.index('buildTypes {'))

    def test_pinned_release_certificate_is_a_sha256(self):
        pinned = (Path(__file__).resolve().parents[1] / 'tool/release_signing_cert.sha256').read_text().strip()
        self.assertRegex(pinned, r'^[0-9a-f]{64}$')

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

    def test_firebase_options_become_native_resources_only_when_configured(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            options = root / 'firebase_options.dart'
            options.write_text("static const FirebaseOptions android = FirebaseOptions(\n apiKey: '',\n appId: '',\n messagingSenderId: '',\n projectId: '',\n);")
            self.assertEqual(module.firebase_options(options), {})
            res = root / 'res'
            (res / 'values').mkdir(parents=True)
            (res / 'values/firebase_config.xml').write_text('stale')
            self.assertFalse(module.create_firebase_resources(res, {}))
            self.assertFalse((res / 'values/firebase_config.xml').exists())
            options.write_text("static const FirebaseOptions android = FirebaseOptions(\n apiKey: 'AIzaTest',\n appId: '1:42:android:abc',\n messagingSenderId: '42',\n projectId: 'demo-app',\n);")
            values = module.firebase_options(options)
            self.assertEqual(values['appId'], '1:42:android:abc')
            self.assertTrue(module.create_firebase_resources(res, values))
            strings = {e.get('name'): e.text for e in ET.parse(res / 'values/firebase_config.xml').getroot()}
            self.assertEqual(strings, {'google_api_key': 'AIzaTest', 'google_app_id': '1:42:android:abc', 'gcm_defaultSenderId': '42', 'project_id': 'demo-app'})

    def test_repository_firebase_options_parse(self):
        values = module.firebase_options()
        if values:
            self.assertRegex(values['appId'], r'^1:\d+:android:[0-9a-f]+$')
            self.assertEqual(values['messagingSenderId'], values['appId'].split(':')[1])

    def test_push_gradle_dependency_is_added_once(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            core = root / 'core/android'
            core.mkdir(parents=True)
            (core / 'gradle.properties').write_text('FirebaseSDKVersion=34.1.0\n')
            config = root / 'package_config.json'
            config.write_text(json.dumps({'packages': [{'name': 'firebase_core', 'rootUri': 'core/'}]}))
            gradle = root / 'build.gradle.kts'
            gradle.write_text('android {}\n')
            module.configure_push_gradle(config, gradle)
            module.configure_push_gradle(config, gradle)
            text = gradle.read_text()
            self.assertEqual(text.count('// B_music02 push'), 1)
            self.assertIn('firebase-bom:34.1.0', text)
            self.assertIn('implementation("com.google.firebase:firebase-messaging")', text)
