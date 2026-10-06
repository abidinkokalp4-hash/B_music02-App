#!/usr/bin/env python3
"""Fail unless an APK is signed with the pinned B Music release certificate.

Every APK must carry the same certificate, otherwise Android refuses to update
an installed copy (Xiaomi's installer reports it as "package appears invalid").
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def apksigner() -> str:
    home = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '')
    tools = sorted((home / 'build-tools').glob('*/apksigner'), key=lambda p: [int(x) if x.isdigit() else 0 for x in re.split(r'[.-]', p.parent.name)])
    if not tools: raise SystemExit('apksigner not found under ANDROID_HOME')
    return str(tools[-1])


def certificate(apk: str) -> str:
    out = subprocess.run([apksigner(), 'verify', '--print-certs', apk], capture_output=True, text=True)
    if out.returncode: raise SystemExit('APK signature does not verify:\n' + out.stdout + out.stderr)
    digests = re.findall(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]{64})', out.stdout)
    if len(digests) != 1: raise SystemExit('Expected exactly one signer:\n' + out.stdout)
    return digests[0]


def main() -> None:
    apk = sys.argv[1]
    pinned = (ROOT / 'tool/release_signing_cert.sha256').read_text().strip()
    actual = certificate(apk)
    print(f'APK signing certificate SHA-256: {actual}', flush=True)
    if actual != pinned:
        raise SystemExit(f'APK is not signed with the B Music release key (expected {pinned})')
    print('PASS: APK signed with the pinned B Music release certificate', flush=True)


if __name__ == '__main__':
    main()
