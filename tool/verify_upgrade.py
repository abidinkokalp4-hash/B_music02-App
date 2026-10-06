#!/usr/bin/env python3
"""Install the previous published release, then update it in place with the new APK.

Releases signed with the pinned key must update without uninstalling. A
previous release signed with a throw-away CI debug key (v1.0.325 and older)
cannot be updated by any later build; that case is reported, not hidden.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_release_signing import certificate  # noqa: E402

PACKAGE = 'com.example.b_music02'
ROOT = Path(__file__).resolve().parents[1]


def adb(*args: str) -> str:
    out = subprocess.run(['adb', *args], capture_output=True, text=True, timeout=180)
    return (out.stdout + out.stderr).strip()


def version() -> str:
    for line in adb('shell', 'dumpsys', 'package', PACKAGE).splitlines():
        if 'versionCode=' in line: return line.split('versionCode=')[1].split()[0]
    return ''


def main() -> None:
    new, previous = sys.argv[1], sys.argv[2]
    if not Path(previous).is_file():
        print('No previous release APK; upgrade check skipped', flush=True); return
    pinned = (ROOT / 'tool/release_signing_cert.sha256').read_text().strip()
    old_cert, new_cert = certificate(previous), certificate(new)
    print(f'previous cert {old_cert}\nnew cert      {new_cert}', flush=True)
    adb('uninstall', PACKAGE)
    first = adb('install', previous)
    if 'Success' not in first: raise SystemExit('Previous release did not install: ' + first)
    old_version = version()
    update = adb('install', '-r', new)
    print(f'update {old_version} -> new: {update}', flush=True)
    if old_cert == new_cert:
        if 'Success' not in update: raise SystemExit('In-place update failed: ' + update)
        print(f'PASS: in-place update from versionCode {old_version} to {version()} kept the app installed', flush=True)
        return
    if old_cert == pinned:
        raise SystemExit('New APK is not signed with the release key; phones could not update: ' + update)
    if 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' not in update:
        raise SystemExit('Unexpected result for a key change: ' + update)
    print('NOTE: the previous release was signed with a temporary CI debug key; phones must uninstall it once. '
          'Every build from now on uses the pinned release key.', flush=True)
    adb('uninstall', PACKAGE)
    fresh = adb('install', new)
    if 'Success' not in fresh: raise SystemExit('Fresh install failed: ' + fresh)
    print(f'PASS: fresh install of the new APK (versionCode {version()})', flush=True)


if __name__ == '__main__':
    main()
