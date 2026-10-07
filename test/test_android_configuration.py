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
            self.assertEqual({x.get(module.A + 'name') for x in services},
                             {'com.ryanheise.audioservice.AudioService', 'com.bmusic.app.VideoPlaybackService',
                              'com.bmusic.app.PushMessagingService', 'com.bmusic.app.AlarmService'})
            push = next(x for x in services if x.get(module.A + 'name') == 'com.bmusic.app.PushMessagingService')
            self.assertEqual(push.get(module.A + 'exported'), 'false')
            self.assertTrue(module.has_action(push, 'com.google.firebase.MESSAGING_EVENT'))
            removed = [x.get(module.A + 'name') for x in app.findall('service') if x.get('{http://schemas.android.com/tools}node') == 'remove']
            self.assertEqual(removed, ['io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService'])
            meta = {x.get(module.A + 'name'): x for x in app.findall('meta-data')}
            self.assertEqual(meta['com.google.firebase.messaging.default_notification_channel_id'].get(module.A + 'value'), 'announcements')
            self.assertEqual(meta['com.google.firebase.messaging.default_notification_icon'].get(module.A + 'resource'), '@drawable/ic_stat_bm')
            self.assertEqual(meta['com.google.firebase.messaging.default_notification_color'].get(module.A + 'resource'), '@color/bm_notification')
            receivers = {x.get(module.A + 'name'): x for x in app.findall('receiver')}
            self.assertEqual(set(receivers), {'com.ryanheise.audioservice.MediaButtonReceiver', 'com.bmusic.app.MusicWidgetProvider', 'com.bmusic.app.AlarmReceiver', 'com.bmusic.app.AlarmBootReceiver'})
            self.assertEqual(receivers['com.bmusic.app.AlarmReceiver'].get(module.A + 'exported'), 'false')
            boot = receivers['com.bmusic.app.AlarmBootReceiver']
            for action in ('android.intent.action.BOOT_COMPLETED', 'android.intent.action.MY_PACKAGE_REPLACED',
                           'android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED'):
                self.assertTrue(module.has_action(boot, action), action)
            alarm = next(x for x in app.findall('activity') if x.get(module.A + 'name') == 'com.bmusic.app.AlarmActivity')
            self.assertEqual(alarm.get(module.A + 'showWhenLocked'), 'true')
            self.assertEqual(alarm.get(module.A + 'turnScreenOn'), 'true')
            self.assertEqual(alarm.get(module.A + 'exported'), 'false')
            provider = next(x for x in app.findall('provider') if x.get(module.A + 'name') == 'com.bmusic.app.UpdateFileProvider')
            self.assertEqual(provider.get(module.A + 'authorities'), 'com.bmusic.app.updates')
            self.assertEqual(provider.get(module.A + 'exported'), 'false')
            self.assertEqual(provider.get(module.A + 'grantUriPermissions'), 'true')
            self.assertEqual(app.get(module.A + 'label'), 'B Music')
            permissions = {e.get(module.A + 'name') for e in root.findall('uses-permission')}
            for name in ('REQUEST_INSTALL_PACKAGES', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED', 'USE_FULL_SCREEN_INTENT', 'VIBRATE'):
                self.assertIn('android.permission.' + name, permissions)
            self.assertNotIn('android.permission.USE_EXACT_ALARM', permissions)
            removed = {e.get(module.A + 'name') for e in root.findall('uses-permission') if e.get(module.TOOLS + 'node') == 'remove'}
            self.assertEqual(removed, set(module.REMOVED_PERMISSIONS))
            self.assertIn('android.permission.ACCESS_ADSERVICES_AD_ID', removed)
            self.assertEqual(meta['google_analytics_adid_collection_enabled'].get(module.A + 'value'), 'false')
            self.assertNotIn('android.permission.RECORD_AUDIO', permissions)
            widget = next(x for x in app.findall('receiver') if x.get(module.A + 'name').endswith('MusicWidgetProvider'))
            self.assertEqual(widget.get(module.A + 'exported'), 'false')
            self.assertTrue(module.has_action(widget, 'android.appwidget.action.APPWIDGET_UPDATE'))
            self.assertEqual(widget.find('meta-data').get(module.A + 'resource'), '@xml/music_widget_info')
            aliases = app.findall('activity-alias')
            self.assertEqual(len(aliases), 3)
            self.assertEqual(sum(x.get(module.A + 'enabled') == 'true' for x in aliases), 1)
            self.assertTrue(all(x.get(module.A + 'targetActivity') == 'com.bmusic.app.MainActivity' for x in aliases))
            self.assertTrue(all(module.has_action(x, 'android.intent.action.MAIN') for x in aliases))
            self.assertTrue(all(x.get(module.A + 'foregroundServiceType') == 'mediaPlayback' for x in services
                                if x.get(module.A + 'name') != 'com.bmusic.app.PushMessagingService'))
            legacy = next(e for e in root.findall('uses-permission') if e.get(module.A + 'name').endswith('READ_EXTERNAL_STORAGE'))
            self.assertEqual(legacy.get(module.A + 'maxSdkVersion'), '32')

    def test_play_store_build_drops_the_updater_and_switches_back(self):
        template = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <uses-permission android:name="android.permission.INTERNET" />
              <application><activity android:name="com.ryanheise.audioservice.AudioServiceActivity">
                <intent-filter><action android:name="android.intent.action.MAIN" /></intent-filter>
              </activity>
              <service android:name="com.ryanheise.audioservice.AudioService" />
              <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" /></application></manifest>'''
        tools_node = '{http://schemas.android.com/tools}node'

        def state(path):
            root = ET.parse(path).getroot()
            app = root.find('application')
            install = next(e for e in root.findall('uses-permission')
                           if e.get(module.A + 'name') == 'android.permission.REQUEST_INSTALL_PACKAGES')
            providers = [x.get(module.A + 'name') for x in app.findall('provider')]
            store = next(x.get(module.A + 'value') for x in app.findall('meta-data')
                         if x.get(module.A + 'name') == 'com.bmusic.app.STORE')
            return install.get(tools_node), 'com.bmusic.app.UpdateFileProvider' in providers, store

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'AndroidManifest.xml'
            path.write_text(template)
            module.configure_manifest(path, 'github')
            github = path.read_text()
            self.assertEqual(state(path), (None, True, 'github'))
            module.configure_manifest(path, 'play')
            play = path.read_text()
            self.assertEqual(state(path), ('remove', False, 'play'))
            module.configure_manifest(path, 'play')
            self.assertEqual(play, path.read_text())
            module.configure_manifest(path, 'github')
            self.assertEqual(state(path), (None, True, 'github'))
            again = path.read_text()
            module.configure_manifest(path, 'github')
            self.assertEqual(again, path.read_text())
            self.assertIn('REQUEST_INSTALL_PACKAGES', github)

    def test_store_comes_from_the_environment(self):
        import os
        from unittest import mock
        with mock.patch.dict(os.environ, {'BMUSIC_STORE': 'play'}):
            self.assertEqual(module.store(), 'play')
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(module.store(), 'github')
        with mock.patch.dict(os.environ, {'BMUSIC_STORE': 'amazon'}):
            with self.assertRaises(SystemExit):
                module.store()

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
            self.assertIn('implementation("com.google.firebase:firebase-analytics")', text)

    def test_package_is_renamed_and_version_name_follows_the_build(self):
        with tempfile.TemporaryDirectory() as directory:
            gradle = Path(directory) / 'build.gradle.kts'
            gradle.write_text('android {\n    namespace = "com.example.b_music02"\n    defaultConfig {\n'
                              '        applicationId = "com.example.b_music02"\n        versionCode = flutter.versionCode\n'
                              '        versionName = flutter.versionName\n    }\n}\n')
            module.configure_package(gradle)
            module.configure_package(gradle)
            text = gradle.read_text()
            self.assertIn('namespace = "com.bmusic.app"', text)
            self.assertIn('applicationId = "com.bmusic.app"', text)
            self.assertIn('versionName = "1.0." + flutter.versionCode', text)
            self.assertNotIn('com.example', text)

    def test_crashlytics_build_id_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            res = Path(directory) / 'res'
            module.create_crashlytics_build_id(res)
            strings = {e.get('name'): e.text for e in ET.parse(res / 'values/crashlytics_build_id.xml').getroot()}
            self.assertRegex(strings['com.google.firebase.crashlytics.mapping_file_id'], r'^[0-9a-f-]{32,36}$')
