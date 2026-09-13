from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = ROOT / 'lib/main.dart'
text = main.read_text(encoding='utf-8')

old = "config: const AudioServiceConfig("
new = "config: AudioServiceConfig("

if old in text:
    text = text.replace(old, new, 1)
elif "config: AudioServiceConfig(" not in text:
    raise SystemExit('AudioServiceConfig block not found')

main.write_text(text, encoding='utf-8')
print('Media notification v2 compile fix applied.')
