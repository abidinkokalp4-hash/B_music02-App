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
    return result.stdout


def screenshot(name: str) -> None:
    with (OUTPUT / (name + ".png")).open("wb") as image:
        subprocess.run(
            ["adb", "-s", SERIAL, "exec-out", "screencap", "-p"],
            stdin=subprocess.DEVNULL, stdout=image, check=True, timeout=30,
        )


def hierarchy() -> ET.Element:
    last = ""
    for _ in range(3):
        adb("shell", "uiautomator", "dump", "/sdcard/bmusic-test-ui.xml",
            check=False)
        last = adb("shell", "cat", "/sdcard/bmusic-test-ui.xml", check=False)
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
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
    try:
        create_tracks()
        open_library()
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
        adb("shell", "input", "keyevent", "KEYCODE_HOME")
        wait_state(3, TITLES[0])
        assert_notification()
        adb("shell", "cmd", "statusbar", "expand-notifications")
        time.sleep(2)
        screenshot("notification-panel")
        ui = hierarchy()
        if not any(TITLES[0] in node.get("text", "") or
                   TITLES[0] in node.get("content-desc", "")
                   for node in ui.iter("node")):
            raise AssertionError("Track title is missing from the notification panel")
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
        if not tap_label("Oynat"):
            raise AssertionError("Completed queue did not offer a play button")
        wait_state(3, TITLES[0])
        assert_notification()
        screenshot("replayed-queue")

        log = adb("logcat", "-d", "-v", "brief", "-s",
                  "flutter:V", "System.err:V", "AndroidRuntime:E")
        if ("You must specify an icon resource id" in log or
                "[B_music02 media error]" in log or "FATAL EXCEPTION" in log):
            raise AssertionError("Android media service logged a runtime error")
        print("PASS: native notification, panel title, play/pause, next/previous "
              "and playback while backgrounded/asleep; completed queue "
              "restarts with one play tap", flush=True)
    finally:
        evidence()


if __name__ == "__main__":
    main()
