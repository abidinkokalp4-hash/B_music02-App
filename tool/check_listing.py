#!/usr/bin/env python3
"""Check the Play listing text limits in store/listing-tr.md (title 30, short 80, full 4000)."""
import re
import sys
from pathlib import Path

LIMITS = {'title': 30, 'short': 80, 'full': 4000}


def sections(text):
    return {key: re.search(rf'<!-- {key} -->\n(.*?)\n<!-- /{key} -->', text, re.S).group(1).strip() for key in LIMITS}


def main(path=Path(__file__).resolve().parents[1] / 'store/listing-tr.md'):
    found = sections(Path(path).read_text())
    ok = True
    for key, limit in LIMITS.items():
        size = len(found[key])
        print(f'{key}: {size}/{limit}')
        ok &= 0 < size <= limit
    if not ok: sys.exit('Listing text exceeds a Play limit')


if __name__ == '__main__':
    main(*sys.argv[1:])
