#!/usr/bin/env python3
"""Check the Google Play App Bundle (B_Music_play.aab) before it is published.

    python3 tool/verify_play_bundle.py B_Music_play.aab MANIFEST.xml [--build N] [--signed]
    python3 tool/verify_play_bundle.py B_Music_play.aab --signed      # signature only

MANIFEST.xml is `bundletool dump manifest --bundle B_Music_play.aab`. The Play
build must:
  * be com.bmusic.app with versionCode N (the CI run number, same as the APK),
  * target the current Play API level (36 since 31 Aug 2026),
  * have no self-updater: no REQUEST_INSTALL_PACKAGES, no update FileProvider,
    and the com.bmusic.app.STORE meta-data set to "play",
  * keep the permissions the features need and none of the advertising ones,
  * with --signed: be signed with the pinned B Music key (the Play upload key).
"""
import argparse
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
A = '{http://schemas.android.com/apk/res/android}'
PACKAGE = 'com.bmusic.app'
MIN_TARGET_SDK = 36   # Play: new apps and updates from 31 Aug 2026
REQUIRED = ('INTERNET', 'POST_NOTIFICATIONS', 'READ_MEDIA_AUDIO', 'READ_MEDIA_VIDEO', 'FOREGROUND_SERVICE',
            'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'WAKE_LOCK', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED',
            'USE_FULL_SCREEN_INTENT')
FORBIDDEN = ('android.permission.REQUEST_INSTALL_PACKAGES', 'android.permission.USE_EXACT_ALARM',
             'com.google.android.gms.permission.AD_ID', 'android.permission.ACCESS_ADSERVICES_AD_ID',
             'android.permission.ACCESS_ADSERVICES_ATTRIBUTION', 'android.permission.RECORD_AUDIO',
             'android.permission.CAMERA', 'android.permission.READ_CONTACTS', 'android.permission.ACCESS_FINE_LOCATION',
             'android.permission.QUERY_ALL_PACKAGES', 'android.permission.MANAGE_EXTERNAL_STORAGE')


def check_manifest(text: str, build: int | None = None) -> list[str]:
    root = ET.fromstring(text)
    problems = []
    if root.get('package') != PACKAGE: problems.append(f'package is {root.get("package")}, expected {PACKAGE}')
    if build is not None and root.get(A + 'versionCode') != str(build):
        problems.append(f'versionCode is {root.get(A + "versionCode")}, expected {build}')
    sdk = root.find('uses-sdk')
    target = int(sdk.get(A + 'targetSdkVersion', '0')) if sdk is not None else 0
    if target < MIN_TARGET_SDK: problems.append(f'targetSdkVersion {target} < {MIN_TARGET_SDK} (Play requirement)')
    permissions = {e.get(A + 'name') for e in root.iter() if e.tag in ('uses-permission', 'uses-permission-sdk-23')}
    for name in FORBIDDEN:
        if name in permissions: problems.append(f'{name} must not be in the Play build')
    for name in REQUIRED:
        if 'android.permission.' + name not in permissions: problems.append(f'android.permission.{name} missing')
    app = root.find('application')
    if app is None: return problems + ['application missing']
    if any(e.get(A + 'name') == PACKAGE + '.UpdateFileProvider' for e in app.findall('provider')):
        problems.append('update FileProvider must not be in the Play build')
    store = next((e.get(A + 'value') for e in app.findall('meta-data') if e.get(A + 'name') == PACKAGE + '.STORE'), None)
    if store != 'play': problems.append(f'{PACKAGE}.STORE meta-data is {store!r}, expected "play"')
    return problems


def certificate(aab: str) -> str:
    verify = subprocess.run(['jarsigner', '-verify', aab], capture_output=True, text=True)
    if verify.returncode or 'jar verified' not in verify.stdout:
        raise SystemExit('App Bundle signature does not verify:\n' + verify.stdout + verify.stderr)
    out = subprocess.run(['keytool', '-printcert', '-jarfile', aab], capture_output=True, text=True)
    digests = {d.replace(':', '').lower() for d in re.findall(r'SHA256:\s*([0-9A-Fa-f:]{95})', out.stdout)}
    if len(digests) != 1: raise SystemExit('Expected exactly one signing certificate:\n' + out.stdout + out.stderr)
    return digests.pop()


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('aab')
    parser.add_argument('manifest', nargs='?')
    parser.add_argument('--build', type=int)
    parser.add_argument('--signed', action='store_true', help='require the pinned B Music (upload) key')
    args = parser.parse_args(argv)
    if not args.manifest and not args.signed: parser.error('give MANIFEST.xml and/or --signed')
    if args.manifest:
        problems = check_manifest(Path(args.manifest).read_text(), args.build)
        if problems: raise SystemExit('Play bundle manifest check failed:\n  ' + '\n  '.join(problems))
        print('PASS: Play bundle manifest (com.bmusic.app, targetSdk >= 36, no REQUEST_INSTALL_PACKAGES, no updater)', flush=True)
    if args.signed:
        pinned = (ROOT / 'tool/release_signing_cert.sha256').read_text().strip()
        actual = certificate(args.aab)
        print(f'App Bundle signing certificate SHA-256: {actual}', flush=True)
        if actual != pinned: raise SystemExit(f'App Bundle is not signed with the B Music upload key (expected {pinned})')
        print('PASS: App Bundle signed with the pinned B Music key (Play upload key)', flush=True)


if __name__ == '__main__':
    main(sys.argv[1:])
