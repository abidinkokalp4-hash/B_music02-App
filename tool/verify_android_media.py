#!/usr/bin/env python3
"""Exercise a release APK's real Android media session on an emulator."""
from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import time
import wave
import xml.etree.ElementTree as ET

PACKAGE = "com.bmusic.app"
OUTPUT = Path("android-media-evidence")
SERIAL = "emulator-" + os.environ.get("EMULATOR_PORT", "5554")
TITLES = ("notification_test_1", "notification_test_2", "notification_test_3")


def adb(*args: str, check: bool = True, timeout: int = 30) -> str:
    result = subprocess.run(
        ["adb", "-s", SERIAL, *args],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=check,
    )
    return result.stdout + (result.stderr if not check and result.returncode else "")


def screenshot(name: str) -> None:
    with (OUTPUT / (name + ".png")).open("wb") as image:
        subprocess.run(
            ["adb", "-s", SERIAL, "exec-out", "screencap", "-p"],
            stdin=subprocess.DEVNULL, stdout=image, check=True, timeout=30,
        )


def hierarchy() -> ET.Element:
    last = ""
    for _ in range(3):
        adb("shell", "rm", "-f", "/sdcard/bmusic-test-ui.xml")
        dumped = adb("shell", "uiautomator", "dump", "/sdcard/bmusic-test-ui.xml",
                     check=False)
        xml = adb("shell", "cat", "/sdcard/bmusic-test-ui.xml", check=False)
        last = xml if "<?xml" in xml else dumped + "\n" + xml
        start = last.find("<?xml")
        if start >= 0:
            try:
                (OUTPUT / "ui.xml").write_text(last[start:])
                return ET.fromstring(last[start:])
            except ET.ParseError:
                pass
        time.sleep(1)
    raise AssertionError("Android UI hierarchy unavailable: " + last[:200])


def ui_label(value: str) -> str:
    # Android all-caps buttons use the device locale; Turkish dotless i may
    # therefore appear as ASCII I on an English-language test emulator.
    return value.casefold().replace("ı", "i").replace("\u0307", "")


def tap_label(label: str, *, partial: bool = False) -> bool:
    for node in hierarchy().iter("node"):
        values = [node.get("text", ""), node.get("content-desc", "")]
        matches = any(ui_label(label) in ui_label(value) if partial else ui_label(label) in ui_label(value).splitlines()
                      for value in values)
        bounds = re.findall(r"\d+", node.get("bounds", ""))
        if not matches or len(bounds) != 4:
            continue
        left, top, right, bottom = map(int, bounds)
        if right <= left or bottom <= top:
            continue
        adb("shell", "input", "tap", str((left + right) // 2),
            str((top + bottom) // 2))
        print("Tapped:", label, flush=True)
        return True
    return False


def session() -> str:
    text = adb("shell", "dumpsys", "media_session")
    (OUTPUT / "media-session.txt").write_text(text)
    start = text.find("package=" + PACKAGE)
    if start < 0:
        start = text.find(PACKAGE + "/")
    return text[start:start + 4500] if start >= 0 else ""


def wait_state(state: int, title: str, timeout: int = 35) -> str:
    deadline = time.monotonic() + timeout
    last = ""
    while time.monotonic() < deadline:
        last = session()
        match = re.search(r"state=PlaybackState\s*\{state=(?:[A-Z_]+\()?(\d+)\)?", last)
        if match and int(match[1]) == state and title in last:
            if state == 3 and "active=true" not in last:
                time.sleep(1)
                continue
            print("Android session:", state, title, flush=True)
            return last
        time.sleep(1)
    raise AssertionError(
        f"Expected Android state={state}, title={title}; got:\n{last[:3000]}"
    )


def assert_notification() -> None:
    text = adb("shell", "dumpsys", "notification", "--noredact")
    (OUTPUT / "notifications.txt").write_text(text)
    if not re.search(r"NotificationRecord\([^\n]*pkg=" + re.escape(PACKAGE),
                     text):
        raise AssertionError("No native media notification was posted")


def test_home_widget() -> None:
    if not tap_label("Ana Sayfa"):
        raise AssertionError("Home tab unavailable for widget installation")
    time.sleep(2)
    screenshot("app-home-playing")
    # The home header has search and a ⋮ menu (İletişim, Öneri Kutusu,
    # Uygulamayı paylaş, Ayarlar); no bell or gear icon any more. The widget
    # action lives under Ayarlar > Bildirimler.
    labels = [n.get("content-desc", "") + "|" + n.get("text", "") for n in hierarchy().iter("node")]
    if any(label.startswith(("Bildirimler|", "Ayarlar|")) for label in labels):
        raise AssertionError("Home header still shows the bell/gear icons: " + str(labels))
    if not tap_label("Daha fazla seçenek"):
        raise AssertionError("Home ⋮ menu unavailable")
    time.sleep(1)
    menu = " ".join(n.get("text", "") + " " + n.get("content-desc", "") for n in hierarchy().iter("node"))
    for item in ("İletişim", "Öneri Kutusu", "Uygulamayı paylaş", "Ayarlar"):
        if item not in menu: raise AssertionError("Home ⋮ menu item missing: " + item)
    screenshot("home-menu")
    if not tap_label("Ayarlar"):
        raise AssertionError("Home settings unavailable")
    time.sleep(2)
    if not tap_label("Bildirimler"):
        raise AssertionError("Notification settings unavailable")
    time.sleep(2)
    if not tap_label("Ana ekran oynatıcısı"):
        raise AssertionError("Widget pin action unavailable")
    time.sleep(2)
    if not (tap_label("Add automatically") or tap_label("ADD AUTOMATICALLY")
            or tap_label("Add") or tap_label("ADD")
            or tap_label("ADD TO HOME SCREEN") or tap_label("Add to home screen")):
        screenshot("widget-pin-dialog")
        raise AssertionError("Launcher did not offer widget installation")
    time.sleep(2)
    # Leave Bildirimler and the settings route so the app is back on home.
    for _ in range(2):
        adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)
    adb("shell", "input", "keyevent", "KEYCODE_HOME")
    time.sleep(2)
    widget_state = adb("shell", "dumpsys", "appwidget")
    (OUTPUT / "appwidget.txt").write_text(widget_state)
    if "MusicWidgetProvider" not in widget_state:
        raise AssertionError("Home widget provider was not registered")
    ui = hierarchy()
    if not any(TITLES[0] in node.get("text", "") for node in ui.iter("node")):
        raise AssertionError("Widget did not display the currently playing title")
    screenshot("home-widget")
    for label, state, title in (
        ("Duraklat", 2, TITLES[0]), ("Oynat", 3, TITLES[0]),
        ("Sonraki şarkı", 3, TITLES[1]), ("Önceki şarkı", 3, TITLES[0]),
    ):
        if not tap_label(label):
            raise AssertionError("Widget control unavailable: " + label)
        wait_state(state, title)
        time.sleep(1)
    screenshot("home-widget-playing")


def create_tracks() -> None:
    rate = 8000
    samples = b"".join(
        struct.pack("<h", int(500 * math.sin(2 * math.pi * 440 * n / rate)))
        for n in range(rate)
    )
    adb("shell", "mkdir", "-p", "/sdcard/Music")
    for title in TITLES:
        path = OUTPUT / (title + ".wav")
        with wave.open(str(path), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            seconds = 12 if title == TITLES[-1] else 300
            for _ in range(seconds):
                audio.writeframesraw(samples)
        remote = "/sdcard/Music/" + path.name
        adb("push", str(path), remote)
        adb("shell", "am", "broadcast",
            "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
            "-d", "file://" + remote)
        path.unlink()
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        library = adb("shell", "content", "query",
                      "--uri", "content://media/external/audio/media",
                      "--projection", "title:_data")
        if all(title in library for title in TITLES):
            (OUTPUT / "indexed-tracks.txt").write_text(library)
            return
        time.sleep(1)
    raise AssertionError("Synthetic test tracks were not indexed by MediaStore")


def open_library() -> None:
    adb("shell", "am", "start", "-n", PACKAGE + "/.IconPurple")
    time.sleep(5)
    # A fresh installation opens the permissions screen. Permissions were
    # granted by install -g, so only its Continue button needs a tap.
    for _ in range(8):
        if tap_label("GOT IT") or tap_label("Got it"):
            time.sleep(1)
            continue
        if tap_label("Atla"):
            time.sleep(2)
            continue
        if tap_label("Uygulamaya devam et"):
            time.sleep(2)
            break
        if tap_label("Müzik"):
            break
        adb("shell", "input", "swipe", "270", "1000", "270", "420", "400")
        time.sleep(1)
    else:
        if not tap_label("Müzik"):
            raise AssertionError("Music library navigation was unavailable")
    time.sleep(2)
    # The library opens on the 'Tümü' overview (artist/album/folder shelves
    # above the songs); the plain song list keeps every test track on screen.
    # A tap during app start-up can be lost, so retry the Müzik navigation.
    for _ in range(5):
        if tap_label("Şarkılar"):
            time.sleep(1)
            return
        tap_label("Müzik")
        time.sleep(2)
    screenshot("music-library-missing")
    raise AssertionError("Music library song tab was unavailable")


def evidence() -> None:
    ui_path = OUTPUT / "ui.xml"
    if ui_path.exists():
        try:
            for node in ET.parse(ui_path).getroot().iter("node"):
                if node.get("text") or node.get("content-desc"):
                    print("Android UI:", {key: node.get(key, "") for key in
                          ("text", "content-desc", "resource-id", "bounds")}, flush=True)
        except (ET.ParseError, OSError):
            pass
    try:
        memory = subprocess.run(["free", "-m"], capture_output=True, text=True,
                                timeout=10, check=False).stdout
        kernel = subprocess.run(["sudo", "dmesg"], capture_output=True, text=True,
                                timeout=10, check=False).stdout
        relevant = "\n".join(line for line in kernel.splitlines() if
                             re.search(r"oom|out of memory|killed process|segfault", line, re.I))
        (OUTPUT / "host-memory.txt").write_text(memory + "\n" + relevant)
        print("Emulator host memory:\n" + memory + relevant, flush=True)
    except (subprocess.SubprocessError, OSError):
        pass
    for name, command in (
        ("native-video-log.txt", ("logcat", "-d", "-v", "threadtime")),
        ("media-session.txt", ("shell", "dumpsys", "media_session")),
        ("notifications.txt", ("shell", "dumpsys", "notification", "--noredact")),
        ("media-log.txt", ("logcat", "-d", "-v", "brief", "-s",
                           "flutter:V", "System.err:V", "AndroidRuntime:E")),
    ):
        try:
            text = adb(*command, check=False)
            (OUTPUT / name).write_text(text)
            if name == "media-log.txt":
                print("Android media diagnostic log:\n" + text[-12000:],
                      flush=True)
        except (subprocess.SubprocessError, OSError) as error:
            print("Evidence capture failed:", name, error, flush=True)
    try:
        screenshot("final-screen")
    except (subprocess.SubprocessError, OSError):
        pass


def video_progress_count() -> int:
    return adb('logcat', '-d', '-v', 'brief', '-s', 'flutter:V').count(
        '[B_music02 video] advancing position=')


def pause_running_video(previous_count: int) -> None:
    # Native decoding can start more slowly on a software-rendered emulator.
    # Require actual clock movement rather than mistaking playing=true for playback.
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        log = adb('logcat', '-d', '-v', 'brief', '-s', 'flutter:V')
        if log.count('[B_music02 video] advancing position=') > previous_count:
            break
        time.sleep(1)
    else:
        raise AssertionError('Native video clock never advanced')
    top = adb('shell', 'dumpsys', 'activity', 'activities')
    print('Video foreground: ' + '\\n'.join(line for line in top.splitlines() if 'ResumedActivity' in line or 'topResumedActivity' in line), flush=True)
    foreground = '\n'.join(line for line in top.splitlines()
                           if 'topResumedActivity=' in line or 'ResumedActivity:' in line)
    if '.VideoActivity' in foreground:
        # A running clock prevents UIAutomator from becoming idle. Tap the
        # native play/pause cell before asking for a paused hierarchy. The
        # bottom panel is: seek bar (32 dp), clock (20 dp) and one 64 dp row
        # (repeat, -10, play/pause, +10, rotate) above 10 dp padding, so the
        # middle cell's centre sits 42 dp above the bottom edge.
        size = adb('shell', 'wm', 'size')
        width, height = map(int, re.findall(r'(\d+)x(\d+)', size)[-1])
        density = adb('shell', 'wm', 'density')
        dpi = int(re.findall(r'(\d+)', density)[-1])
        x = width // 2
        y = height - round(42 * dpi / 160)
        marker = '[BMusic feature] native-playing=false'
        before = adb('logcat', '-d', '-v', 'brief', '-s', 'flutter:V').count(marker)
        for attempt in range(3):
            # Controls auto-hide while playing: a tap on the hidden play cell
            # only reveals them, so the next attempt taps the same cell again.
            # (A centre tap would hide visible controls instead.)
            adb('shell', 'input', 'tap', str(x), str(y))
            time.sleep(.9)
            log = adb('logcat', '-d', '-v', 'brief', '-s', 'flutter:V')
            if log.count(marker) > before:
                if not any('Oynat' == n.get('content-desc', '') for n in hierarchy().iter('node')):
                    raise AssertionError('Native pause did not expose its play control')
                return
        raise AssertionError('Native pause button did not pause playback')
    for _ in range(3):
        # First tap also reveals controls if their auto-hide timer elapsed.
        adb('shell', 'input', 'tap', '270', '570')
        time.sleep(0.5)
        ui = hierarchy()
        if any('Oynat' in n.get('content-desc', '') for n in ui.iter('node')):
            return
    raise AssertionError('Running video could not be paused')


def test_local_video() -> None:
    path = OUTPUT / 'local_video_test.mp4'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                    '-f', 'lavfi', '-i', 'color=c=0x33224a:s=320x240:r=10',
                    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100',
                    '-t', '70', '-c:a', 'aac', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', str(path)],
                   check=True, timeout=60)
    remote = '/sdcard/Movies/local_video_test.mp4'
    adb('push', str(path), remote)
    adb('shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d', 'file://' + remote)
    if not tap_label('Video'):
        raise AssertionError('Local video navigation unavailable')
    progress_before_open = video_progress_count()
    for _ in range(20):
        if tap_label('local_video_test', partial=True):
            break
        time.sleep(1)
    else:
        raise AssertionError('Local MP4 did not appear in the video library')
    pause_running_video(progress_before_open)
    if not tap_label('10 saniye ileri'):
        raise AssertionError('Local video player controls unavailable')
    screenshot('local-video-playing')
    values = [n.get('text', '') + ' ' + n.get('content-desc', '') for n in hierarchy().iter('node')]
    if not any(8 <= int(x) <= 30 for value in values for x in re.findall(r'0:(\d{2})', value)):
        raise AssertionError('Local video seek did not advance playback')
    if not tap_label('Geri'):
        raise AssertionError('Local video back button unavailable')
    time.sleep(2)
    screenshot('local-video-resume-card')
    progress_before_open = video_progress_count()
    if not tap_label('local_video_test', partial=True):
        raise AssertionError('Local video could not be reopened')
    pause_running_video(progress_before_open)
    values = [n.get('text', '') + ' ' + n.get('content-desc', '') for n in hierarchy().iter('node')]
    if not any(8 <= int(x) <= 30 for value in values for x in re.findall(r'0:(\d{2})', value)):
        raise AssertionError('Reopened video did not retain its playback position')
    screenshot('local-video-resumed')
    test_video_feature_pack()
    tap_label('Geri')
    print('PASS: local MP4 playback, seek and persistent resume while offline', flush=True)



def native_log() -> str:
    return adb('logcat', '-d', '-v', 'brief', '-s', 'flutter:V')


def node_labels() -> list[str]:
    return [n.get('content-desc', '') or n.get('text', '') for n in hierarchy().iter('node')]


def sheet_open() -> bool:
    return 'Oynatma hızı' in node_labels() or 'Sayfayı kapat' in node_labels()


def video_tool(label: str) -> None:
    """Open the ⋮ bottom sheet and pick a row (scrolling inside the sheet)."""
    for _ in range(3):
        if sheet_open() or tap_label('Video araçları'): break
        # Controls hidden while playing: one tap in the middle shows them.
        adb('shell', 'input', 'tap', '270', '450')
        time.sleep(.8)
    else: raise AssertionError('Video tools (⋮) missing')
    time.sleep(.6)
    for _ in range(5):
        if tap_label(label): time.sleep(.6); return
        adb('shell', 'input', 'swipe', '270', '1000', '270', '600', '300')
        time.sleep(.5)
    raise AssertionError('Tool missing from the ⋮ sheet: ' + label)


def close_sheet_outside() -> None:
    adb('shell', 'input', 'tap', '270', '40')
    time.sleep(.8)
    if sheet_open(): raise AssertionError('Tapping outside did not close the ⋮ sheet')


def double_tap(x: int, y: int) -> bool:
    marker = '[BMusic feature] favorite='
    before = native_log().count(marker)
    for _ in range(3):
        # Start the second tap ~0.1 s after the first so both land inside 240 ms
        # regardless of how long one `input` call takes on the emulator.
        adb('shell', f'(input tap {x} {y} &); sleep 0.1; input tap {x} {y}; sleep 0.3')
        time.sleep(1.2)
        if native_log().count(marker) > before: return True
    return False


def test_video_feature_pack() -> None:
    # Operate only the disposable emulator's local MP4 fixture (paused).
    nodes = node_labels()
    for label in ['Geri', 'Video araçları', 'Tekrar oynat', '10 saniye geri', 'Oynat', '10 saniye ileri',
                  'Yatay / dikey döndür', 'Video süresi']:
        if label not in nodes: raise AssertionError('Native player control missing: ' + label)
    # The old right panel and bottom tab bar are gone.
    for label in ['Favorilere ekle', 'Kısa klip çıkar', 'Tam ekran', 'Videoyu kes', 'Yüzen videoyu aç', 'Fotoğraf al']:
        if label in nodes: raise AssertionError('Removed player control still visible: ' + label)
    if 'Parlaklık' in nodes or 'Ses' in nodes: raise AssertionError('Brightness/volume bars are always visible')
    screenshot('video-portrait-controls')
    # Double tap toggles the favorite (heart + toast), twice back to the start.
    if not double_tap(270, 450): raise AssertionError('Double tap did not toggle the favorite')
    first = re.findall(r'favorite=(true|false)', native_log())[-1]
    screenshot('video-double-tap-favorite')
    if not double_tap(270, 450): raise AssertionError('Second double tap did not toggle the favorite back')
    second = re.findall(r'favorite=(true|false)', native_log())[-1]
    if first == second: raise AssertionError('Favorite did not toggle')
    # Single tap hides / shows the controls.
    before = native_log().count('[BMusic feature] tap controls=')
    adb('shell', 'input', 'tap', '270', '450')
    time.sleep(.8)
    if native_log().count('[BMusic feature] tap controls=') <= before: raise AssertionError('Single tap did not toggle controls')
    if 'Video araçları' in node_labels():
        adb('shell', 'input', 'tap', '270', '450'); time.sleep(.8)
        raise AssertionError('Single tap did not hide the controls')
    adb('shell', 'input', 'tap', '270', '450')
    time.sleep(.8)
    if 'Video araçları' not in node_labels(): raise AssertionError('Single tap did not show the controls again')
    # ⋮ sheet: sections, rows, red Sil, no KAPAT button, no duplicates.
    if not tap_label('Video araçları'): raise AssertionError('Video tools missing')
    time.sleep(.8)
    if '[BMusic feature] sheet=open' not in native_log(): raise AssertionError('⋮ sheet did not open')
    screenshot('video-tools-sheet')
    seen: set[str] = set()
    for _ in range(4):
        nodes = list(hierarchy().iter('node'))
        # Rows carry their label as content-desc (child texts repeat it).
        rows = [n.get('content-desc', '') for n in nodes if n.get('content-desc') and n.get('content-desc') != 'Sayfayı kapat']
        # The player's own controls stay in the tree under the sheet's scrim.
        under = {'Geri', 'Video araçları', 'Tekrar oynat', 'Tekrar oynat: açık', '10 saniye geri', 'Oynat',
                 'Duraklat', '10 saniye ileri', 'Yatay / dikey döndür', 'Video süresi'}
        dupes = {x for x in rows if rows.count(x) > (2 if x in under else 1)}
        if dupes: raise AssertionError('Duplicate rows in the ⋮ sheet: ' + str(dupes))
        seen.update(rows)
        seen.update(n.get('text', '') for n in nodes if n.get('text'))
        adb('shell', 'input', 'swipe', '270', '1000', '270', '500', '300')
        time.sleep(.5)
    for label in ['OYNATMA', 'DÜZENLE', 'DOSYA', 'Oynatma hızı', 'Tekrar oynat', 'Ekranı doldur', 'Ekran kilidi',
                  'Yüzen video', 'Uyku zamanlayıcısı', 'Ekran kapalı dinleme', 'Altyazı ekle', 'Kırp', 'GIF oluştur',
                  'Ekran görüntüsü', 'Sesi kaydet', 'Video bilgileri', 'Paylaş', 'Klasöre taşı', 'Yeniden adlandır', 'Sil']:
        if label not in seen: raise AssertionError('⋮ sheet row missing: ' + label + ' in ' + str(sorted(seen)))
    if any(ui_label(x) == ui_label('Kapat') for x in seen): raise AssertionError('The ⋮ sheet must not have a KAPAT button')
    screenshot('video-tools-sheet-bottom')
    # Swipe down on the sheet closes it.
    for _ in range(3):
        adb('shell', 'input', 'swipe', '270', '700', '270', '1100', '200')
        time.sleep(.3)
    time.sleep(.8)
    if sheet_open(): raise AssertionError('Swiping down did not close the ⋮ sheet')
    # Sleep timer through the sheet's choice page.
    video_tool('Uyku zamanlayıcısı')
    if not tap_label('15 dakika'): raise AssertionError('Sleep timer choices missing')
    time.sleep(1)
    if '[BMusic feature] sleep=15' not in native_log(): raise AssertionError('Sleep timer was not armed')
    video_tool('Uyku zamanlayıcısı')
    if not tap_label('Kapalı'): raise AssertionError('Sleep timer could not be cancelled')
    time.sleep(1)
    if '[BMusic feature] sleep=0' not in native_log(): raise AssertionError('Sleep timer was not cancelled')
    # Speed choice page.
    video_tool('Oynatma hızı')
    if not tap_label('1.5×') and not tap_label('1,5×'): raise AssertionError('Speed choices missing')
    time.sleep(.8)
    if '[BMusic feature] speed=1.5' not in native_log(): raise AssertionError('Speed was not applied')
    video_tool('Oynatma hızı')
    if not tap_label('1.0×'): raise AssertionError('Normal speed missing')
    time.sleep(.8)
    # Portrait: horizontal/vertical swipes must NOT seek or change brightness/volume.
    log_before = native_log()
    counts = {m: log_before.count('[BMusic feature] ' + m) for m in ('seek=', 'brightness=', 'volume=')}
    for coords in [('100', '480', '430', '480', '350'), ('40', '650', '40', '380', '350'), ('500', '650', '500', '380', '350')]:
        adb('shell', 'input', 'swipe', *coords)
        time.sleep(.6)
    log = native_log()
    for marker, count in counts.items():
        if log.count('[BMusic feature] ' + marker) != count: raise AssertionError('Portrait gesture must be disabled: ' + marker)
    # Landscape: seek, brightness (left), volume (right), hold right for 2x.
    if 'Yatay / dikey döndür' not in node_labels():
        adb('shell', 'input', 'tap', '270', '450'); time.sleep(.8)
    if not tap_label('Yatay / dikey döndür'): raise AssertionError('Rotate button missing')
    time.sleep(2)
    for coords in [('250', '200', '850', '200', '350'), ('30', '300', '30', '125', '350'),
                   ('1110', '300', '1110', '125', '350'), ('900', '200', '900', '200', '1300')]:
        adb('shell', 'input', 'swipe', *coords)
        time.sleep(.6)
    log = native_log()
    for marker in ['seek=', 'brightness=', 'volume=', 'hold=2.0', 'release=1.0']:
        if '[BMusic feature] ' + marker not in log:
            raise AssertionError('Missing landscape video gesture: ' + marker)
    time.sleep(1.5)
    screenshot('video-landscape')
    nodes = node_labels()
    if 'Parlaklık' in nodes or 'Ses' in nodes: raise AssertionError('Landscape brightness/volume bars stay visible')
    if 'Yatay / dikey döndür' not in nodes:
        adb('shell', 'input', 'tap', '570', '270'); time.sleep(.8)
    if not tap_label('Yatay / dikey döndür'): raise AssertionError('Portrait return missing')
    time.sleep(2)
    if 'Video süresi' not in node_labels():
        adb('shell', 'input', 'tap', '270', '450'); time.sleep(.8)
    # Seek bar scrub: a preview bubble with a frame, no thumbnail strip.
    for node in hierarchy().iter('node'):
        if node.get('content-desc') == 'Video süresi':
            x1, y1, x2, y2 = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
            adb('shell', 'input', 'swipe', str(x1 + 40), str((y1 + y2) // 2), str(x2 - 40), str((y1 + y2) // 2), '2000')
            time.sleep(.5)
            # Back to the beginning for the clip export below.
            adb('shell', 'input', 'swipe', str(x2 - 40), str((y1 + y2) // 2), str(x1 + 2), str((y1 + y2) // 2), '600')
            break
    else: raise AssertionError('Video timeline missing')
    if '[BMusic feature] preview=' not in native_log():
        raise AssertionError('Scrub preview did not produce a frame')
    time.sleep(1)
    video_tool('Kırp')
    if not tap_label('Kaydet'): raise AssertionError('Clip save missing')
    deadline = time.monotonic() + 100
    while time.monotonic() < deadline:
        listing = adb('shell', 'content', 'query', '--uri', 'content://media/external/video/media', '--projection', '_display_name:_size')
        if 'BMusic_Klip_' in listing: break
        time.sleep(2)
    else: raise AssertionError('Clip not published to video library')
    screenshot('video-clip-export')
    video_tool('Sesi kaydet')
    deadline = time.monotonic() + 100
    while time.monotonic() < deadline:
        listing = adb('shell', 'content', 'query', '--uri', 'content://media/external/audio/media', '--projection', '_display_name:_size')
        if 'BMusic_Ses_' in listing: break
        time.sleep(2)
    else: raise AssertionError('Audio export not published')
    # Inspect actual outputs, not just completion messages.
    import json
    listing = adb('shell', 'find', '/sdcard/Movies/BMusic', '/sdcard/Music/BMusic', '-type', 'f')
    for remote in listing.splitlines():
        if 'BMusic_Klip_' not in remote and 'BMusic_Ses_' not in remote: continue
        local = OUTPUT / Path(remote).name
        adb('pull', remote, str(local))
        probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=codec_type', '-of', 'json', str(local)], text=True)
        info = json.loads(probe)
        duration = float(info['format']['duration'])
        assert duration > 0
        kinds = {stream['codec_type'] for stream in info['streams']}
        if 'BMusic_Klip_' in remote: assert 'video' in kinds and duration <= 31
        else: assert kinds == {'audio'} and duration > 65
    video_tool('Video bilgileri')
    screenshot('video-information')
    if not tap_label('Tamam'): raise AssertionError('Video information dialog unavailable')
    time.sleep(.6)
    video_tool('GIF oluştur')
    if not tap_label('3 saniye'): raise AssertionError('GIF duration selection unavailable')
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        # While IS_PENDING=1 the file is hidden as .pending-*; wait for the published name.
        listing = adb('shell', 'find', '/sdcard/Pictures/BMusic', '-name', '*.gif', check=False)
        published = [line.strip() for line in listing.splitlines()
                     if line.strip().endswith('.gif') and not Path(line.strip()).name.startswith('.')]
        if published: break
        time.sleep(1)
    else: raise AssertionError('GIF export not published')
    time.sleep(2)
    local_gif = OUTPUT / Path(published[0]).name
    adb('pull', published[0], str(local_gif))
    gif_info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'stream=codec_name,width,nb_frames', '-of', 'json', str(local_gif)], text=True))['streams'][0]
    assert gif_info['codec_name'] == 'gif' and gif_info['width'] <= 320 and int(gif_info['nb_frames']) > 1
    screenshot('video-gif-export')
    # Screen-off listening (toggled in place), then close by tapping outside.
    video_tool('Ekran kapalı dinleme')
    close_sheet_outside()
    if 'Oynat' not in node_labels():
        adb('shell', 'input', 'tap', '270', '450'); time.sleep(.8)
    if not tap_label('Oynat'): raise AssertionError('Play missing for background test')
    adb('shell', 'input', 'keyevent', 'KEYCODE_SLEEP')
    time.sleep(3)
    session = adb('shell', 'dumpsys', 'media_session')
    if 'VideoPlaybackService' not in session and 'local_video_test' not in session:
        raise AssertionError('Background video session missing')
    wait_state(3, 'local_video_test')
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    adb('shell', 'wm', 'dismiss-keyguard', check=False)
    adb('shell', 'cmd', 'media_session', 'dispatch', 'pause')
    time.sleep(.5)
    screenshot('video-feature-pack')
    video_tool('Yüzen video')
    time.sleep(1)
    if '[BMusic feature] pip-actions=3' not in native_log(): raise AssertionError('PiP window lacks its 10 s / play-pause controls')
    time.sleep(2)
    if 'pinned' not in adb('shell', 'dumpsys', 'activity', 'activities').lower(): raise AssertionError('Video did not enter picture-in-picture')
    screenshot('video-floating')
    # Bring the existing singleTask Flutter activity forward, then reopen local video.
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    time.sleep(2)
    tap_label('Video')
    progress_before_open = video_progress_count()
    if not tap_label('local_video_test', partial=True): raise AssertionError('Video unavailable after floating playback')
    pause_running_video(progress_before_open)
    print('PASS: decluttered player (top bar, one transport row), double-tap favorite, ⋮ sheet sections/rows/'
          'swipe & outside close, portrait without gestures, landscape seek/volume/brightness/hold 2x, '
          'scrub preview, real MP4/M4A/GIF exports, screen-off audio and PiP', flush=True)


def leave_video_player() -> None:
    for _ in range(3):
        top = adb('shell', 'dumpsys', 'activity', 'activities')
        if not any('.VideoActivity' in line for line in top.splitlines()
                   if 'topResumedActivity=' in line or 'ResumedActivity:' in line): return
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        time.sleep(1.5)


def test_codec_fallback() -> None:
    """AC3 audio (no platform decoder on the emulator) must play natively through the
    bundled FFmpeg audio decoder; a container ExoPlayer cannot read (WMV/ASF)
    must reopen in the software (libmpv) player instead of failing."""
    leave_video_player()
    ac3 = OUTPUT / 'codec_ac3_test.mkv'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                    '-f', 'lavfi', '-i', 'testsrc2=s=320x240:r=15', '-f', 'lavfi', '-i', 'sine=frequency=330:sample_rate=48000',
                    '-t', '40', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'ac3', '-b:a', '192k', str(ac3)], check=True, timeout=90)
    wmv = OUTPUT / 'codec_wmv_test.wmv'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                    '-f', 'lavfi', '-i', 'testsrc2=s=320x240:r=15', '-f', 'lavfi', '-i', 'sine=frequency=550:sample_rate=44100',
                    '-t', '40', '-c:v', 'wmv2', '-b:v', '500k', '-c:a', 'wmav2', str(wmv)], check=True, timeout=90)
    for path in (ac3, wmv):
        remote = '/sdcard/Movies/' + path.name
        adb('push', str(path), remote)
        adb('shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', 'file://' + remote)
    time.sleep(3)
    # Re-enter the Video tab so the library picks up the new files.
    tap_label('Ana Sayfa'); time.sleep(1)
    if not tap_label('Video'): raise AssertionError('Video tab unavailable for codec tests')
    time.sleep(2)
    tap_label('Yenile')
    time.sleep(4)
    progress = video_progress_count()
    errors = native_log().count('native-error=')
    for _ in range(20):
        if tap_label('codec_ac3_test', partial=True): break
        adb('shell', 'input', 'swipe', '270', '900', '270', '500', '300')
        time.sleep(1)
    else: raise AssertionError('AC3 fixture did not appear in the video library')
    pause_running_video(progress)
    if native_log().count('native-error=') != errors: raise AssertionError('AC3 audio failed in the native player')
    decoders = re.findall(r'audio-decoder=(\S+)', native_log())
    print('Audio decoders used:', decoders, flush=True)
    if not decoders or 'ffmpeg' not in decoders[-1].lower(): raise AssertionError('AC3 was not decoded by the bundled FFmpeg decoder: ' + str(decoders))
    screenshot('codec-ac3-native')
    leave_video_player()
    time.sleep(1)
    before = native_log().count('[BMusic feature] software-fallback')
    for _ in range(20):
        if tap_label('codec_wmv_test', partial=True): break
        adb('shell', 'input', 'swipe', '270', '900', '270', '500', '300')
        time.sleep(1)
    else: raise AssertionError('WMV fixture did not appear in the video library')
    deadline = time.monotonic() + 40
    while native_log().count('[BMusic feature] software-fallback') <= before:
        if time.monotonic() > deadline: raise AssertionError('Unsupported video did not fall back to the software player')
        time.sleep(1)
    deadline = time.monotonic() + 40
    while '[BMusic feature] software-position=' not in native_log():
        if time.monotonic() > deadline: raise AssertionError('Software player did not advance')
        time.sleep(1)
    screenshot('codec-wmv-software')
    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    time.sleep(2)
    print('PASS: AC3 audio via the bundled FFmpeg decoder; WMV reopens in the software player and plays', flush=True)


def test_alarm() -> None:
    """Alarm under Daha Fazla: create with a library song, exact AlarmManager entry,
    ring (full screen over the lock screen), snooze, stop, reschedule after boot."""
    # Android 14 denies exact alarms to sideloaded apps until the user allows
    # them (the app shows a banner for that); grant both special accesses here.
    adb('shell', 'appops', 'set', PACKAGE, 'SCHEDULE_EXACT_ALARM', 'allow', check=False)
    adb('shell', 'appops', 'set', PACKAGE, 'USE_FULL_SCREEN_INTENT', 'allow', check=False)
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    time.sleep(4)
    if not tap_label('Daha Fazla'): raise AssertionError('Daha Fazla tab unavailable')
    time.sleep(1)
    if not tap_label('Alarm'): raise AssertionError('Alarm entry missing under Daha Fazla')
    time.sleep(2)
    screenshot('alarm-list')
    if not tap_label('Alarm ekle'): raise AssertionError('Alarm add button missing')
    time.sleep(2)
    if not tap_label('Alarm şarkısı'): raise AssertionError('Alarm song picker missing')
    time.sleep(2)
    if not tap_label(TITLES[0], partial=True): raise AssertionError('Library song missing in the alarm picker')
    time.sleep(1)
    screenshot('alarm-editor')
    before = native_log().count('[BMusic feature] alarms-scheduled=')
    if not tap_label('Kaydet'): raise AssertionError('Alarm save missing')
    deadline = time.monotonic() + 15
    while native_log().count('[BMusic feature] alarms-scheduled=') <= before:
        if time.monotonic() > deadline: raise AssertionError('Alarm was not scheduled')
        time.sleep(1)
    if 'alarms-scheduled=1 exact=true' not in native_log(): raise AssertionError('Alarm is not exact: ' + native_log()[-400:])
    screenshot('alarm-saved')
    alarms = adb('shell', 'dumpsys', 'alarm')
    (OUTPUT / 'alarm-dumpsys.txt').write_text(alarms)
    if PACKAGE not in alarms: raise AssertionError('No AlarmManager entry for the alarm')
    prefs = adb('shell', 'cat', f'/data/data/{PACKAGE}/shared_prefs/bm_alarms.xml')
    match = re.search(r'&quot;id&quot;:(\d+)', prefs)
    if not match: raise AssertionError('Stored alarm missing: ' + prefs[:300])
    ident = match[1]

    def fire() -> None:
        adb('shell', 'am', 'broadcast', '-n', PACKAGE + '/.AlarmReceiver', '-a', 'com.bmusic.app.ALARM_FIRE', '--ei', 'alarm_id', ident)
        deadline = time.monotonic() + 15
        while native_log().count(f'alarm-ringing id={ident}') <= rings:
            if time.monotonic() > deadline: raise AssertionError('Alarm did not ring')
            time.sleep(1)

    adb('shell', 'input', 'keyevent', 'KEYCODE_SLEEP')
    time.sleep(2)
    rings = native_log().count(f'alarm-ringing id={ident}')
    fire()
    if f'song={TITLES[0]}' not in native_log(): raise AssertionError('Alarm did not use the chosen song')
    time.sleep(3)
    top = adb('shell', 'dumpsys', 'activity', 'activities')
    if 'AlarmActivity' not in top: raise AssertionError('Full-screen alarm did not open over the lock screen')
    screenshot('alarm-ringing')
    shade = adb('shell', 'dumpsys', 'notification', '--noredact')
    (OUTPUT / 'alarm-notification.txt').write_text(shade)
    if 'bmusic_alarm' not in shade: raise AssertionError('Alarm notification missing')
    if not tap_label('Ertele', partial=True): raise AssertionError('Snooze button missing')
    deadline = time.monotonic() + 10
    while f'alarm-snoozed id={ident}' not in native_log():
        if time.monotonic() > deadline: raise AssertionError('Snooze did not work')
        time.sleep(1)
    rings = native_log().count(f'alarm-ringing id={ident}')
    fire()
    time.sleep(3)
    if not tap_label('Durdur'): raise AssertionError('Stop button missing')
    time.sleep(2)
    if 'AlarmService' in adb('shell', 'dumpsys', 'activity', 'services', PACKAGE): raise AssertionError('Alarm kept ringing after Durdur')
    adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
    adb('shell', 'wm', 'dismiss-keyguard', check=False)
    before = native_log().count('[BMusic feature] alarms-scheduled=')
    adb('shell', 'am', 'broadcast', '-n', PACKAGE + '/.AlarmBootReceiver', '-a', 'android.intent.action.BOOT_COMPLETED')
    deadline = time.monotonic() + 15
    while native_log().count('[BMusic feature] alarms-scheduled=') <= before:
        if time.monotonic() > deadline: raise AssertionError('Alarms were not restored after boot')
        time.sleep(1)
    print('PASS: alarm with a library song is scheduled exactly, rings full screen over the lock screen, snoozes, stops and is restored after boot', flush=True)


def test_mpeg_external_and_feed() -> None:
    path = OUTPUT / 'wedding_mpeg_test.mpg'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                    '-f', 'lavfi', '-i', 'testsrc2=s=320x240:r=25',
                    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100',
                    '-t', '45', '-c:v', 'mpeg2video', '-b:v', '600k',
                    '-c:a', 'mp2', '-b:a', '128k', '-f', 'mpeg', str(path)],
                   check=True, timeout=60)
    remote = '/sdcard/Movies/wedding_mpeg_test.mpg'
    adb('push', str(path), remote)
    adb('shell', 'am', 'broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', 'file://' + remote)
    media_id = None
    for _ in range(20):
        listing = adb('shell', 'content', 'query', '--uri', 'content://media/external/video/media', '--projection', '_id:_display_name')
        for row in listing.splitlines():
            if 'wedding_mpeg_test.mpg' in row:
                match = re.search(r'_id=(\d+)', row)
                if match: media_id = match[1]
        if media_id: break
        time.sleep(1)
    if not media_id: raise AssertionError('MPEG fixture was not indexed')
    uri = 'content://media/external/video/media/' + media_id
    resolved = adb('shell', 'cmd', 'package', 'query-activities', '--brief',
                   '-a', 'android.intent.action.VIEW', '-d', uri, '-t', 'video/mpeg')
    if PACKAGE not in resolved: raise AssertionError('B Music absent from Open With for MPEG')
    progress_before_open = video_progress_count()
    adb('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', uri,
        '-t', 'video/mpeg', '-n', PACKAGE + '/.MainActivity', '--grant-read-uri-permission')
    pause_running_video(progress_before_open)
    if not tap_label('10 saniye ileri'): raise AssertionError('MPEG controls unavailable')
    values = [n.get('text', '') + ' ' + n.get('content-desc', '') for n in hierarchy().iter('node')]
    if not any(8 <= int(x) <= 30 for value in values for x in re.findall(r'0:(\d{2})', value)):
        raise AssertionError('MPEG seeking failed')
    screenshot('mpeg-external-seek')
    video_tool('Ekran görüntüsü')
    time.sleep(2)
    images = adb('shell', 'content', 'query', '--uri', 'content://media/external/images/media', '--projection', '_display_name:_size')
    if 'BMusic_' not in images: raise AssertionError('Video snapshot not saved to gallery')
    (OUTPUT / 'saved-frames.txt').write_text(images)
    video_tool('Paylaş')
    time.sleep(2)
    screenshot('video-share-sheet')
    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    time.sleep(1)
    if not tap_label('Geri'): adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    time.sleep(2)
    tap_label('Video')
    time.sleep(2)
    # Reels: tapping a video opens the player with the current list; a
    # vertical swipe in the middle 40% pages to the previous/next video.
    # local_video_test is the oldest fixture (last in the newest-first list),
    # so swipe down to reach the previous one.
    progress_before_open = video_progress_count()
    for _ in range(10):
        if tap_label('local_video_test', partial=True): break
        time.sleep(1)
    else: raise AssertionError('Local MP4 unavailable for reels')
    pause_running_video(progress_before_open)
    before = native_log().count('[BMusic feature] reels-index=')
    if any(re.fullmatch(r'\s*\d+\s*/\s*\d+\s*', n.get('text', '')) for n in hierarchy().iter('node')):
        raise AssertionError('The reels index (e.g. "3 / 25") must stay hidden')
    adb('shell', 'input', 'swipe', '270', '250', '270', '850', '250')
    deadline = time.monotonic() + 10
    while native_log().count('[BMusic feature] reels-index=') <= before:
        if time.monotonic() > deadline: raise AssertionError('Vertical reels swipe did not change video')
        time.sleep(.5)
    time.sleep(2)
    screenshot('video-reels-previous')
    # Leave the native player; the next test force-stops the app anyway.
    for _ in range(2):
        top = adb('shell', 'dumpsys', 'activity', 'activities')
        if not any('.VideoActivity' in line for line in top.splitlines()
                   if 'topResumedActivity=' in line or 'ResumedActivity:' in line): break
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        time.sleep(1.5)
    print('PASS: offline MPEG-2/MP2 content URI, seeking, frame capture, sharing and reels swipe', flush=True)


def test_announcements() -> None:
    """Feed a test announcements.json (never the real one on main) through the
    app-private debug_url preference, which only a root shell can write."""
    adb('root', check=False, timeout=60)
    adb('wait-for-device', timeout=60)
    for _ in range(20):
        if 'uid=0' in adb('shell', 'id', check=False): break
        time.sleep(1)
    else: raise AssertionError('adb root unavailable on the test emulator')
    data = f'/data/data/{PACKAGE}'
    prefs = f'{data}/shared_prefs/bmusic_announcements.xml'
    feed = f'{data}/shared_prefs/ci-announcements.json'
    stamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    new_id = 'ci-' + str(int(time.time()))
    title = 'CI duyuru testi'
    import json
    payload = {'announcements': [
        {'id': 'ci-old', 'title': 'Eski duyuru', 'body': 'Gösterilmemeli', 'createdAt': '2000-01-01T00:00:00Z'},
        {'id': new_id, 'title': title, 'body': 'Bildirim ve Duyurular listesi testi', 'createdAt': stamp},
    ]}
    local = OUTPUT / 'ci-announcements.json'
    local.write_text(json.dumps(payload, ensure_ascii=False))
    adb('shell', 'am', 'force-stop', PACKAGE)
    time.sleep(1)
    current = adb('shell', 'cat', prefs, check=False)
    if '<map' not in current: raise AssertionError('Announcement state was never stored: ' + current[:200])
    current = re.sub(r'\s*<string name="debug_url">[^<]*</string>', '', current)
    def write_private(path: str, text: str, reference: str) -> None:
        tmp = OUTPUT / 'private-upload'
        tmp.write_text(text)
        adb('push', str(tmp), '/data/local/tmp/bmusic-upload')
        adb('shell', f'cat /data/local/tmp/bmusic-upload > {path} && '
                     f'chown $(stat -c %u:%g {reference}) {path} && chmod 660 {path} && '
                     f'chcon $(ls -Z {reference} | cut -d" " -f1) {path}')
    write_private(feed, local.read_text(), prefs)
    write_private(prefs, current.replace('</map>', f'    <string name="debug_url">file://{feed}</string>\n</map>'), prefs)
    before = native_log().count('[BMusic feature] announcement-posted')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    deadline = time.monotonic() + 30
    while f'announcement-posted id={new_id}' not in native_log():
        if time.monotonic() > deadline: raise AssertionError('Announcement notification was not posted')
        time.sleep(1)
    time.sleep(1)
    log = native_log()
    if 'announcement-posted id=ci-old' in log: raise AssertionError('An announcement older than the install was notified')
    if log.count('[BMusic feature] announcement-posted') != before + 1: raise AssertionError('Unexpected number of announcement notifications')
    shade = adb('shell', 'dumpsys', 'notification', '--noredact')
    if title not in shade: raise AssertionError('Announcement missing from the notification shade')
    (OUTPUT / 'announcement-notification.txt').write_text(shade)
    # Tapping the notification opens the in-app Duyurular list.
    adb('shell', 'cmd', 'statusbar', 'expand-notifications', check=False)
    time.sleep(2)
    screenshot('announcement-notification')
    if tap_label(title):
        deadline = time.monotonic() + 15
        while f'announcement-opened id={new_id}' not in native_log():
            if time.monotonic() > deadline: raise AssertionError('Announcement tap did not reach the app')
            time.sleep(1)
        time.sleep(2)
        screenshot('announcement-in-app')
        if not any(title in (n.get('text', '') + n.get('content-desc', '')) for n in hierarchy().iter('node')):
            raise AssertionError('Duyurular list did not show the tapped announcement')
    else:
        adb('shell', 'cmd', 'statusbar', 'collapse', check=False)
        raise AssertionError('Announcement notification not found in the shade')
    # Re-checking (fresh start) must not notify the same id again. force-stop
    # also clears the app's notifications, so this runs after the tap check.
    adb('shell', 'am', 'force-stop', PACKAGE)
    checks = native_log().count('[BMusic feature] announcements total=')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    deadline = time.monotonic() + 30
    while native_log().count('[BMusic feature] announcements total=') <= checks:
        if time.monotonic() > deadline: raise AssertionError('Second announcement check did not run')
        time.sleep(1)
    if native_log().count(f'announcement-posted id={new_id}') != 1: raise AssertionError('Announcement was notified twice')
    # Restore the real source for anything that runs afterwards.
    adb('shell', 'am', 'force-stop', PACKAGE)
    write_private(prefs, re.sub(r'\s*<string name="debug_url">[^<]*</string>', '', adb('shell', 'cat', prefs)), prefs)
    adb('shell', 'rm', '-f', feed, '/data/local/tmp/bmusic-upload')
    print('PASS: announcement feed posts one notification for a new id, skips pre-install ones, never repeats, and opens Duyurular on tap', flush=True)
    return new_id


def test_push(seen_id: str) -> None:
    """The CI emulator has no Google Play services, so real FCM delivery is
    impossible. As root, hand the app the same RECEIVE broadcast Play services
    sends (FirebaseInstanceIdReceiver → PushMessagingService) to prove the
    native push path: notification on the Duyurular channel, one notification
    per id (shared with announcements.json), pushed entry in the Duyurular list."""
    adb('shell', 'am', 'force-stop', PACKAGE)
    before = native_log().count('[BMusic feature] push-sync')
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
    deadline = time.monotonic() + 30
    while native_log().count('[BMusic feature] push-sync') <= before:
        if time.monotonic() > deadline: raise AssertionError('Push topic setup did not run at start-up')
        time.sleep(1)
    time.sleep(4)
    stamp = str(int(time.time()))
    push_id, title = 'ci-push-' + stamp, 'CI-anlik-bildirim'

    def deliver(ident: str, suffix: str) -> str:
        return adb('shell', 'am', 'broadcast', '-a', 'com.google.android.c2dm.intent.RECEIVE', '-p', PACKAGE,
                   '--es', 'id', ident, '--es', 'title', title, '--es', 'body', 'FCM-yolu-testi',
                   '--es', 'from', '/topics/all', '--es', 'google.message_id', f'0:{stamp}{suffix}', check=False)

    def wait_log(marker: str, what: str, detail: str = '') -> None:
        deadline = time.monotonic() + 30
        while marker not in native_log():
            if time.monotonic() > deadline: raise AssertionError(what + ' ' + detail)
            time.sleep(1)

    out = deliver(push_id, 'a')
    wait_log(f'push-received id={push_id} posted=true', 'Simulated push was not handled:', out)
    shade = adb('shell', 'dumpsys', 'notification', '--noredact')
    if title not in shade: raise AssertionError('Push notification missing from the notification shade')
    (OUTPUT / 'push-notification.txt').write_text(shade)
    deliver(push_id, 'b')
    wait_log(f'push-duplicate id={push_id}', 'A repeated push id was not recognised')
    deliver(seen_id, 'c')
    wait_log(f'push-duplicate id={seen_id}', 'A push for an id already shown from announcements.json was not skipped')
    if native_log().count(f'push-received id={push_id}') != 1: raise AssertionError('Push was handled twice')
    adb('shell', 'cmd', 'statusbar', 'expand-notifications', check=False)
    time.sleep(2)
    screenshot('push-notification')
    if not tap_label(title):
        adb('shell', 'cmd', 'statusbar', 'collapse', check=False)
        raise AssertionError('Push notification not found in the shade')
    wait_log(f'announcement-opened id={push_id}', 'Push notification tap did not reach the app')
    time.sleep(2)
    screenshot('push-in-app')
    if not any(title in (n.get('text', '') + n.get('content-desc', '')) for n in hierarchy().iter('node')):
        raise AssertionError('Duyurular list did not show the pushed announcement')
    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    print('PASS: simulated FCM push posts one notification per id (shared with announcements.json), '
          'shows in Duyurular and opens it on tap; app runs without Google Play services', flush=True)


def test_external_audio() -> None:
    listing = adb('shell', 'content', 'query', '--uri', 'content://media/external/audio/media',
                  '--projection', '_id:_display_name')
    for index, title in enumerate(TITLES[:2]):
        row = next((row for row in listing.splitlines() if title in row), '')
        match = re.search(r'_id=(\d+)', row)
        if not match: raise AssertionError('External audio fixture unavailable')
        uri = 'content://media/external/audio/media/' + match[1]
        resolved = adb('shell', 'cmd', 'package', 'query-activities', '--brief',
                       '-a', 'android.intent.action.VIEW', '-d', uri, '-t', 'audio/wav')
        if PACKAGE not in resolved: raise AssertionError('B Music absent from audio Open With')
        if index == 0: adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', uri,
            '-t', 'audio/wav', '-n', PACKAGE + '/.MainActivity', '--grant-read-uri-permission')
        wait_state(3, title)
        assert_notification()
        screenshot('external-audio-' + ('cold' if index == 0 else 'warm'))
    print('PASS: audio Open With and content URI playback on cold and warm launch', flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--video-only", action="store_true",
                        help="Reuse a previously verified APK and exercise video plus external audio")
    args = parser.parse_args()
    OUTPUT.mkdir(exist_ok=True)
    # All installation, permissions, media files and power controls are confined
    # to a disposable emulator; never run these operations on a physical phone.
    if adb("shell", "getprop", "ro.kernel.qemu").strip() != "1":
        raise RuntimeError("This runtime test requires an Android emulator")
    adb("shell", "wm", "size", "540x1140")
    adb("shell", "wm", "density", "220")
    adb("shell", "settings", "put", "secure",
        "immersive_mode_confirmations", "confirmed")
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard", check=False)
    adb("shell", "svc", "bluetooth", "disable", check=False)
    adb("install", "-g", str(args.apk), timeout=120)
    adb("logcat", "-c")
    live_log = (OUTPUT / "media-live-log.txt").open("w")
    log_process = subprocess.Popen(
        ["adb", "-s", SERIAL, "logcat", "-v", "brief", "-s",
         "flutter:V", "System.err:V", "AndroidRuntime:E"],
        stdin=subprocess.DEVNULL, stdout=live_log, stderr=subprocess.DEVNULL,
    )
    try:
        adb("shell", "svc", "wifi", "disable")
        adb("shell", "svc", "data", "disable")
        create_tracks()
        open_library()
        if not args.video_only:
            for _ in range(15):
                if tap_label(TITLES[0], partial=True):
                    break
                time.sleep(1)
            else:
                raise AssertionError("Test track did not appear in the music library")
            wait_state(3, TITLES[0])
            assert_notification()
            for action, state, title in (
                ("pause", 2, TITLES[0]),
                ("play", 3, TITLES[0]),
                ("next", 3, TITLES[1]),
                ("previous", 3, TITLES[0]),
            ):
                adb("shell", "cmd", "media_session", "dispatch", action)
                wait_state(state, title)
            test_home_widget()
            adb("shell", "input", "keyevent", "KEYCODE_HOME")
            wait_state(3, TITLES[0])
            assert_notification()
            adb("shell", "cmd", "statusbar", "expand-notifications")
            time.sleep(2)
            screenshot("notification-panel")
            # The animated Android media seek bar prevents UIAutomator idling.
            # Keep the playing screenshot, then pause briefly to read a fresh tree.
            adb("shell", "cmd", "media_session", "dispatch", "pause")
            wait_state(2, TITLES[0])
            time.sleep(1)
            ui = hierarchy()
            if not any(TITLES[0] in node.get("text", "") or
                       TITLES[0] in node.get("content-desc", "")
                       for node in ui.iter("node")):
                raise AssertionError("Track title is missing from the notification panel")
            adb("shell", "cmd", "media_session", "dispatch", "play")
            wait_state(3, TITLES[0])
            adb("shell", "cmd", "statusbar", "collapse")
            adb("shell", "input", "keyevent", "KEYCODE_SLEEP")
            time.sleep(2)
            wait_state(3, TITLES[0])
            assert_notification()
            adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
            time.sleep(2)
            screenshot("lock-screen")

            # just_audio retains playing=true on natural completion. Verify that
            # Android is paused and the in-app play button restarts on one tap.
            adb("shell", "wm", "dismiss-keyguard", check=False)
            open_library()
            if not tap_label(TITLES[-1], partial=True):
                raise AssertionError("The short final test track was unavailable")
            wait_state(3, TITLES[-1])
            wait_state(2, TITLES[-1])
            completed_log = adb("logcat", "-d", "-v", "brief", "-s", "flutter:V")
            if "playing=false processing=completed" not in completed_log:
                raise AssertionError("The queue did not complete naturally")
            screenshot("completed-queue")
            # The mini player slides down after a few seconds; its handle
            # (or a swipe up) brings it back with the play button.
            if tap_label("Mini oynatıcıyı göster"):
                time.sleep(1)
            if not tap_label("Oynat"):
                raise AssertionError("Completed queue did not offer a play button")
            wait_state(3, TITLES[0])
            assert_notification()
            screenshot("replayed-queue")

        test_local_video()
        test_codec_fallback()
        test_mpeg_external_and_feed()
        test_external_audio()
        test_push(test_announcements())
        test_alarm()
        log = adb("logcat", "-d", "-v", "brief", "-s",
                  "flutter:V", "System.err:V", "AndroidRuntime:E")
        if ("ic_stat_music" in log or "You must specify an icon resource id" in log or
                "[B_music02 media error]" in log or "FATAL EXCEPTION" in log):
            raise AssertionError("Android media service logged a runtime error")
        if args.video_only:
            print("PASS: local video feature pack, MPEG/feed and external audio", flush=True)
            return
        print("PASS: native notification, panel title, play/pause, next/previous "
              "and playback while backgrounded/asleep; completed queue "
              "restarts with one play tap; launcher widget metadata and all "
              "four playback controls", flush=True)
    finally:
        try:
            evidence()
        finally:
            log_process.terminate()
            try:
                log_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                log_process.kill()
                log_process.wait(timeout=5)
            live_log.close()


if __name__ == "__main__":
    main()
