#!/usr/bin/env python3
"""Google Play phone screenshots of the real app, captured on the CI emulator.

    python3 tool/capture_store_screenshots.py release/app-release.apk

Runs only on a disposable emulator. The screen is set to 1080x1920 (16:9, the
Play limit is 2:1), the status bar is put in demo mode, and the library is
filled with media generated here by ffmpeg (tones and abstract visuals, no
third-party content). Raw PNGs land in store-screenshots/; tool/store_assets.py
--frame adds the captioned copies.
"""
import importlib.util
import re
import shlex
from urllib.parse import quote
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('media', ROOT / 'tool/verify_android_media.py')
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)
OUT = Path('store-screenshots')
media.OUTPUT = OUT
adb, tap_label, hierarchy = media.adb, media.tap_label, media.hierarchy
PACKAGE = media.PACKAGE
WORK = OUT / 'media'

# Fictional demo catalogue (generated audio, abstract covers).
SONGS = [
    ('Gece Yolculuğu', 'Neon Rüyası', 'Şehir Işıkları', (196, 247, 294), 0x6a1bff),
    ('Sabah Kahvesi', 'Ada Sesleri', 'Güne Başla', (262, 330, 392), 0xff7a3d),
    ('Mavi Dalga', 'Deniz Kıyısı', 'Yaz Akşamı', (220, 277, 330), 0x2bb8ff),
    ('Kuzey Rüzgârı', 'Lumen Trio', 'Dağ Evi', (174, 220, 262), 0x37d39a),
    ('Yıldız Tozu', 'Neon Rüyası', 'Şehir Işıkları', (233, 294, 349), 0xc04dff),
    ('Yağmurdan Sonra', 'Ada Sesleri', 'Güne Başla', (196, 233, 294), 0x4d7cff),
    ('Altın Saat', 'Lumen Trio', 'Dağ Evi', (247, 311, 370), 0xffc23d),
    ('Ritim 88', 'Kuzey Ekspresi', 'Hareket', (165, 208, 247), 0xff3d8b),
]
VIDEOS = [
    ('Mor Dalgalar', 'gradients=s=1080x1920:c0=0x1a0533:c1=0xa53cff:c2=0x2bd2ff:c3=0x0b0220:n=4:speed=0.015:r=25'),
    ('Renk Girdabı', 'gradients=s=540x960:c0=0x2a0b45:c1=0xff3d8b:c2=0xffc23d:c3=0x6a1bff:n=4:type=spiral:speed=0.02:r=25,scale=1080:1920'),
    ('Gün Batımı', 'gradients=s=1080x1920:c0=0xff7a3d:c1=0xc0306f:c2=0x2a0b45:n=3:speed=0.02:r=25'),
    ('Neon Şehir', 'gradients=s=1920x1080:c0=0x050510:c1=0x00e5ff:c2=0xff00aa:c3=0x1b0b2e:n=4:speed=0.03:r=25'),
    ('Okyanus Mavisi', 'gradients=s=1920x1080:c0=0x001f3f:c1=0x0074d9:c2=0x7fdbff:n=3:speed=0.01:r=25'),
    ('Hayat Oyunu', 'life=s=270x480:mold=10:r=25:ratio=0.12:death_color=#12051f:life_color=#c77dff,scale=1080:1920:flags=neighbor'),
]


def ffmpeg(*args, timeout=240):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *args], check=True, timeout=timeout)


def make_cover(path, colour, seed):
    """Abstract album art: radial glow, soft circles and a vinyl ring (no text)."""
    import random
    from PIL import Image, ImageDraw, ImageFilter
    rng = random.Random(seed)
    size = 600
    rgb = ((colour >> 16) & 255, (colour >> 8) & 255, colour & 255)
    image = Image.new('RGB', (size, size), (11, 2, 32))
    glow = Image.new('L', (size, size), 0)
    cx, cy = rng.randint(150, 450), rng.randint(150, 450)
    ImageDraw.Draw(glow).ellipse((cx - 330, cy - 330, cx + 330, cy + 330), fill=230)
    image = Image.composite(Image.new('RGB', (size, size), rgb), image, glow.filter(ImageFilter.GaussianBlur(140)))
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for _ in range(7):
        r = rng.randint(40, 170)
        x, y = rng.randint(0, size), rng.randint(0, size)
        tint = tuple(min(255, v + rng.randint(20, 90)) for v in rgb) + (rng.randint(40, 110),)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=tint)
    layer = layer.filter(ImageFilter.GaussianBlur(6))
    draw = ImageDraw.Draw(layer)
    for r, alpha in ((190, 160), (150, 70), (110, 50), (30, 220)):
        draw.ellipse((300 - r, 300 - r, 300 + r, 300 + r), outline=(255, 255, 255, alpha), width=3 if r > 30 else 30)
    image = Image.alpha_composite(image.convert('RGBA'), layer).convert('RGB')
    image.save(path)


MUSIC_DIR = '/sdcard/Music/BMusicDemo'
VIDEO_DIR = '/sdcard/Movies/BMusicDemo'


def push_and_scan(local, remote, timeout):
    adb('push', str(local), remote, timeout=timeout)
    adb('shell', 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d ' + shlex.quote('file://' + quote(remote)))


def generate_media():
    """Runs on the host before the emulator starts (encoding next to a running
    emulator is several times slower)."""
    WORK.mkdir(parents=True, exist_ok=True)
    for index, (title, artist, album, notes, colour) in enumerate(SONGS):
        cover = WORK / f'cover{index}.png'
        make_cover(cover, colour, index * 7 + 1)
        chord = '+'.join(f'0.12*sin(2*PI*{f}*t)*(0.6+0.4*sin(2*PI*{0.5 + i * 0.25}*t))' for i, f in enumerate(notes))
        ffmpeg('-f', 'lavfi', '-i', f'aevalsrc={chord}:s=22050:d={150 + index * 23}',
               '-i', str(cover), '-map', '0:a', '-map', '1:v', '-c:a', 'libmp3lame', '-b:a', '48k',
               '-c:v', 'png', '-disposition:v', 'attached_pic', '-id3v2_version', '4',
               '-metadata', f'title={title}', '-metadata', f'artist={artist}', '-metadata', f'album={album}',
               '-metadata', 'genre=Demo', str(WORK / f'song{index}.mp3'))
        print('generated', title, flush=True)
    for index, (title, source) in enumerate(VIDEOS):
        ffmpeg('-f', 'lavfi', '-i', source + ',scale=720:-2', '-f', 'lavfi', '-i', f'sine=frequency={220 + index * 55}:sample_rate=22050',
               '-t', str(18 + index * 7), '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p', '-b:v', '900k',
               '-c:a', 'aac', '-b:a', '48k', '-shortest', str(WORK / f'video{index}.mp4'))
        print('generated', title, flush=True)


def make_media():
    if not (WORK / f'video{len(VIDEOS) - 1}.mp4').exists(): generate_media()
    # `adb shell` joins its arguments into one shell command line, so paths with
    # spaces or Turkish letters are quoted here.
    adb('shell', 'mkdir -p ' + shlex.quote(MUSIC_DIR) + ' ' + shlex.quote(VIDEO_DIR))
    for index, (title, *_rest) in enumerate(SONGS):
        push_and_scan(WORK / f'song{index}.mp3', f'{MUSIC_DIR}/{title}.mp3', 60)
    for index, (title, _source) in enumerate(VIDEOS):
        push_and_scan(WORK / f'video{index}.mp4', f'{VIDEO_DIR}/{title}.mp4', 120)
    time.sleep(5)


def demo_status_bar():
    adb('shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1')
    for extra in (['enter'], ['clock', '-e', 'hhmm', '0930'],
                  ['battery', '-e', 'level', '100', '-e', 'plugged', 'false'],
                  ['network', '-e', 'wifi', 'show', '-e', 'level', '4'],
                  ['network', '-e', 'mobile', 'show', '-e', 'datatype', 'none', '-e', 'level', '4'],
                  ['notifications', '-e', 'visible', 'false']):
        adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', *extra, check=False)


STARTED = time.monotonic()


def shot(name):
    time.sleep(1.5)
    print(f'[{time.monotonic() - STARTED:.0f}s]', end=' ', flush=True)
    path = OUT / f'{name}.png'
    with path.open('wb') as image:
        subprocess.run(['adb', '-s', media.SERIAL, 'exec-out', 'screencap', '-p'], stdout=image, check=True, timeout=30)
    print('Screenshot:', path, flush=True)


def tap_any(*labels, partial=False, tries=4):
    for _ in range(tries):
        for label in labels:
            if tap_label(label, partial=partial): return True
        time.sleep(1)
    return False


def first_run():
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.IconPurple')
    time.sleep(6)
    for _ in range(8):
        if tap_label('GOT IT') or tap_label('Got it') or tap_label('Atla'):
            time.sleep(1.5); continue
        if tap_label('Uygulamaya devam et'):
            time.sleep(2); break
        if 'Ana Sayfa' in media.node_labels(): break
        adb('shell', 'input', 'swipe', '540', '1600', '540', '600', '400')
        time.sleep(1)
    time.sleep(2)


def open_full_player(title, artist, retry=True):
    """Tap the mini player card (title + artist, lowest on screen)."""
    best = None
    for node in hierarchy().iter('node'):
        label = node.get('content-desc', '') + '\n' + node.get('text', '')
        bounds = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if title in label and artist in label and len(bounds) == 4 and bounds[1] > 1300:
            if best is None or bounds[1] > best[1]: best = bounds
    if best is None:
        if not retry: return False
        tap_label('Mini oynatıcıyı göster'); time.sleep(1)
        return open_full_player(title, artist, retry=False)
    adb('shell', 'input', 'tap', str(best[0] + 140), str((best[1] + best[3]) // 2))
    time.sleep(2.5)
    return True


def main():
    if sys.argv[1:] == ['--generate']:
        generate_media()
        return
    apk = Path(sys.argv[1])
    if adb('shell', 'getprop', 'ro.kernel.qemu').strip() != '1':
        raise SystemExit('Store screenshots are taken on an Android emulator only')
    for old in OUT.glob('*.png'): old.unlink()
    OUT.mkdir(exist_ok=True)
    adb('shell', 'wm', 'size', '1080x1920')
    adb('shell', 'wm', 'density', '420')
    adb('shell', 'settings', 'put', 'secure', 'immersive_mode_confirmations', 'confirmed')
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    adb('shell', 'wm', 'dismiss-keyguard', check=False)
    adb('install', '-r', '-g', str(apk), timeout=180)
    adb('shell', 'appops', 'set', PACKAGE, 'SCHEDULE_EXACT_ALARM', 'allow', check=False)
    adb('shell', 'appops', 'set', PACKAGE, 'USE_FULL_SCREEN_INTENT', 'allow', check=False)
    make_media()
    demo_status_bar()
    adb('logcat', '-c')
    first_run()
    # Music: play one song so the home screen and mini player look alive.
    tap_any('Müzik'); time.sleep(2)
    tap_any('Şarkılar'); time.sleep(2)
    # The top row of the alphabetical list (ASCII-safe title).
    title, artist = next((s[0], s[1]) for s in SONGS if s[0] == 'Altın Saat')
    for _ in range(10):
        if tap_label(title, partial=True): break
        time.sleep(1)
    else:
        tap_any('Tümünü çal')
    time.sleep(3)
    shot('02-music')
    if open_full_player(title, artist):
        shot('03-player')
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1.5)
    tap_any('Ana Sayfa'); time.sleep(2)
    adb('shell', 'cmd', 'media_session', 'dispatch', 'pause', check=False)
    shot('01-home')
    # Videos
    tap_any('Video'); time.sleep(3)
    tap_any('Yenile'); time.sleep(3)
    shot('04-videos')
    progress = media.video_progress_count()
    if tap_any(VIDEOS[0][0], partial=True):
        try:
            media.pause_running_video(progress)
        except AssertionError as error:
            print('note:', error, flush=True)
        shot('05-video-player')
        if tap_any('Video araçları') or (adb('shell', 'input', 'tap', '540', '700') is not None and tap_any('Video araçları')):
            time.sleep(1.5)
            shot('06-video-tools')
            adb('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)
        media.leave_video_player()
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity'); time.sleep(2)
    # Alarm with a library song
    if tap_any('Daha Fazla') and tap_any('Alarm'):
        time.sleep(2)
        if tap_any('Alarm ekle'):
            time.sleep(2)
            if tap_any('Alarm şarkısı'):
                time.sleep(2)
                tap_any(SONGS[1][0], partial=True); time.sleep(1)
            tap_any('Kaydet'); time.sleep(2)
        shot('07-alarm')
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK'); time.sleep(1)
    # Settings from the home ⋮ menu
    tap_any('Ana Sayfa'); time.sleep(1.5)
    if tap_any('Daha fazla seçenek') and tap_any('Ayarlar'):
        time.sleep(2)
        shot('08-settings')
    adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'exit', check=False)
    shots = sorted(p.name for p in OUT.glob('*.png'))
    print('Captured:', shots, flush=True)
    if len(shots) < 6: raise SystemExit('Fewer than 6 store screenshots were captured')


if __name__ == '__main__':
    main()
