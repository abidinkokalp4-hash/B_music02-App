import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('bundle', Path(__file__).resolve().parents[1] / 'tool/verify_play_bundle.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

PERMS = ''.join(f'<uses-permission android:name="android.permission.{p}"/>' for p in module.REQUIRED)


def manifest(extra='', target=36, store='play', app_extra=''):
    return (f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.bmusic.app" '
            f'android:versionCode="350"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="{target}"/>'
            f'{PERMS}{extra}<application><meta-data android:name="com.bmusic.app.STORE" android:value="{store}"/>'
            f'{app_extra}</application></manifest>')


class PlayBundleTest(unittest.TestCase):
    def test_clean_play_manifest_passes(self):
        self.assertEqual(module.check_manifest(manifest(), 350), [])

    def test_updater_permission_provider_and_store_are_rejected(self):
        bad = manifest('<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>', store='github',
                       app_extra='<provider android:name="com.bmusic.app.UpdateFileProvider"/>')
        problems = '\n'.join(module.check_manifest(bad))
        self.assertIn('REQUEST_INSTALL_PACKAGES', problems)
        self.assertIn('FileProvider', problems)
        self.assertIn('STORE', problems)

    def test_target_sdk_and_version_code(self):
        problems = '\n'.join(module.check_manifest(manifest(target=35), 351))
        self.assertIn('targetSdkVersion 35', problems)
        self.assertIn('versionCode', problems)


if __name__ == '__main__':
    unittest.main()
