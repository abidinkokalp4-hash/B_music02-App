"""Check the final release APK for dynamically resolved notification/media icons
(ic_stat_bm is the white BM silhouette used by every notification)."""

import re
import sys
from pathlib import Path


REQUIRED_MEDIA_ICONS = (
    'ic_stat_bm',
    'audio_service_play_arrow',
    'audio_service_pause',
    'audio_service_skip_previous',
    'audio_service_skip_next',
    'audio_service_stop',
    'audio_service_fast_forward',
    'audio_service_fast_rewind',
)


def verify_resources(resource_dump: str) -> None:
    available = set(re.findall(
        r'^\s*resource\s+0x[0-9a-fA-F]+\s+drawable/([A-Za-z0-9_]+)\b',
        resource_dump,
        flags=re.MULTILINE,
    ))
    missing = set(REQUIRED_MEDIA_ICONS) - available
    if missing:
        raise RuntimeError(
            'APK medya kontrol simgeleri eksik: ' + ', '.join(sorted(missing))
        )


if __name__ == '__main__':
    verify_resources(Path(sys.argv[1]).read_text())
    print(f'APK medya kontrol simgeleri doğrulandı: {len(REQUIRED_MEDIA_ICONS)}')
