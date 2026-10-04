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

PACKAGE = "com.example.b_music02"
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


def tap_label(label: str, *, partial: bool = False) -> bool:
    for node in hierarchy().iter("node"):
        values = [node.get("text", ""), node.get("content-desc", "")]
        matches = any(label in value if partial else label in value.splitlines()
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
    if not tap_label("Uygulama menüsü"):
        raise AssertionError("Home menu unavailable")
    if not tap_label("Ana ekrana oynatıcı ekle"):
        raise AssertionError("Widget pin action unavailable")
    time.sleep(2)
    if not (tap_label("Add automatically") or tap_label("ADD AUTOMATICALLY")
            or tap_label("Add") or tap_label("ADD")
            or tap_label("ADD TO HOME SCREEN") or tap_label("Add to home screen")):
        screenshot("widget-pin-dialog")
        raise AssertionError("Launcher did not offer widget installation")
    time.sleep(2)
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
            return
        adb("shell", "input", "swipe", "270", "1000", "270", "420", "400")
        time.sleep(1)
    if not tap_label("Müzik"):
        raise AssertionError("Music library navigation was unavailable")
    time.sleep(2)


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
                    '-t', '70', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', str(path)],
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
    tap_label('Geri')
    print('PASS: local MP4 playback, seek and persistent resume while offline', flush=True)



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
    if not tap_label('1…1707 tokens truncated…    "and playback while backgrounded/asleep; completed queue "
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
