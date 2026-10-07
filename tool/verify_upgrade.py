#!/usr/bin/env python3
"""Install the previous published release, then update it in place with the new APK.

Releases signed with the pinned key must update without uninstalling. A
previous release signed with a throw-away CI debug key (v1.0.325 and older)
cannot be updated by any later build; that case is reported, not hidden.

The package name changed once (com.example.b_music02 -> com.bmusic.app). When
the previous release has a different package, Android treats the new APK as a
different app: phones need one uninstall + install, which is reported as a
NOTE and checked as a fresh install next to the old app.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_release_signing import certificate  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def adb(*args: str) -> str:
    out = subprocess.run(['adb', *args], capture_output=True, text=True, timeout=180)
    return (out.stdout + out.stderr).strip()


def aapt2() -> str:
    home = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '')
    tools = sorted((home / 'build-tools').glob('*/aapt2'),
                   key=lambda p: [int(x) if x.isdigit() else 0 for x in re.split(r'[.-]', p.parent.name)])
    if not tools: raise SystemExit('aapt2 not found under ANDROID_HOME')
    return str(tools[-1])


def package_of(apk: str) -> str:
    out = subprocess.run([aapt2(), 'dump', 'packagename', apk], capture_output=True, text=True)
    name = out.stdout.strip().splitlines()[-1].strip() if out.stdout.strip() else ''
    if out.returncode or not re.fullmatch(r'[A-Za-z0-9_.]+', name):
        raise SystemExit('Could not read the package name of ' + apk + ':\n' + out.stdout + out.stderr)
    return name


def version(package: str) -> str:
    for line in adb('shell', 'dumpsys', 'package', package).splitlines():
        if 'versionCode=' in line: return line.split('versionCode=')[1].split()[0]
    return ''


def main() -> None:
    new, previous = sys.argv[1], sys.argv[2]
    if not Path(previous).is_file():
        print('No previous release APK; upgrade check skipped', flush=True); return
    pinned = (ROOT / 'tool/release_signing_cert.sha256').read_text().strip()
    old_cert, new_cert = certificate(previous), certificate(new)
    old_package, new_package = package_of(previous), package_of(new)
    print(f'previous {old_package} cert {old_cert}\nnew      {new_package} cert {new_cert}', flush=True)
    if new_cert != pinned:
        raise SystemExit('New APK is not signed with the pinned release key')
    adb('uninstall', old_package)
    adb('uninstall', new_package)
    first = adb('install', previous)
    if 'Success' not in first: raise SystemExit('Previous release did not install: ' + first)
    old_version = version(old_package)
    if old_package != new_package:
        print(f'NOTE: package changed {old_package} -> {new_package}. Android installs the new APK as a separate app; '
              f'phones must uninstall {old_package} once and install the new APK (data is not carried over).', flush=True)
        fresh = adb('install', new)
        print(f'install next to {old_package} {old_version}: {fresh}', flush=True)
        if 'Success' not in fresh: raise SystemExit('Fresh install of the new package failed: ' + fresh)
        print(f'PASS: {new_package} versionCode {version(new_package)} installs next to the old app', flush=True)
        adb('uninstall', old_package)
        return
    update = adb('install', '-r', new)
    print(f'update {old_version} -> new: {update}', flush=True)
    if old_cert == new_cert:
        if 'Success' not in update: raise SystemExit('In-place update failed: ' + update)
        print(f'PASS: in-place update from versionCode {old_version} to {version(new_package)} kept the app installed', flush=True)
        return
    if old_cert == pinned:
        raise SystemExit('New APK is not signed with the release key; phones could not update: ' + update)
    if 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' not in update:
        raise SystemExit('Unexpected result for a key change: ' + update)
    print('NOTE: the previous release was signed with a temporary CI debug key; phones must uninstall it once. '
          'Every build from now on uses the pinned release key.', flush=True)
    adb('uninstall', new_package)
    fresh = adb('install', new)
    if 'Success' not in fresh: raise SystemExit('Fresh install failed: ' + fresh)
    print(f'PASS: fresh install of the new APK (versionCode {version(new_package)})', flush=True)


if __name__ == '__main__':
    main()
