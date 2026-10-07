"""Configure the generated Android project for B Music (CI runs `flutter create`
first, then this script).

Package: com.bmusic.app (Play Store id). The template is generated as
com.example.b_music02; namespace/applicationId, Kotlin sources and every
manifest component are moved to PKG here.
"""
from pathlib import Path
import html
import json
import re
import shutil
import uuid
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
PKG = "com.bmusic.app"
TEMPLATE_PKG = "com.example.b_music02"
LABEL = "B Music"
# App background (lib/core/theme/app_theme.dart AppColors.background) and accent.
BACKGROUND = "#FF030305"
ACCENT = "#FFA53CFF"
MEDIA3 = "1.11.1"
# Media3 FFmpeg audio decoders (AC-3/E-AC-3/DTS/TrueHD/... that phones often
# lack). Maintained by Jellyfin, LGPL, published on Maven Central.
FFMPEG_DECODER = "org.jellyfin.media3:media3-ffmpeg-decoder:1.9.0+1"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
A = f"{{{ANDROID_NS}}}"
TOOLS = "{http://schemas.android.com/tools}"
ET.register_namespace("android", ANDROID_NS)
ET.register_namespace("tools", "http://schemas.android.com/tools")

# Runtime permissions/features and why they are needed: docs/PLAY_STORE.md.
PERMISSIONS = {
    "WAKE_LOCK": None,                      # playback and alarms with the screen off
    "FOREGROUND_SERVICE": None,
    "FOREGROUND_SERVICE_MEDIA_PLAYBACK": None,  # music, video audio and alarm sound
    "READ_MEDIA_AUDIO": None,
    "READ_MEDIA_VIDEO": None,
    "READ_EXTERNAL_STORAGE": 32,
    "WRITE_EXTERNAL_STORAGE": 28,
    "POST_NOTIFICATIONS": None,
    "REQUEST_INSTALL_PACKAGES": None,       # in-app update (GitHub APK builds only)
    "SCHEDULE_EXACT_ALARM": None,           # alarm music rings on time
    "RECEIVE_BOOT_COMPLETED": None,         # alarms survive a reboot
    "USE_FULL_SCREEN_INTENT": None,         # ringing alarm over the lock screen
    "VIBRATE": None,                        # alarm vibration
    "INTERNET": None,                       # Firebase (push, Crashlytics, Analytics, feedback), update check (kept last: re-added
                                            # after removing duplicates)
}


def android_name(e):
    return e.get(A + "name")


def cls(name):
    return f"{PKG}.{name}"


def ensure_permission(root, name, max_sdk=None):
    full = f"android.permission.{name}"
    e = next((x for x in root.findall("uses-permission") if android_name(x) == full), None)
    if e is None:
        e = ET.SubElement(root, "uses-permission", {A + "name": full})
    if max_sdk is not None:
        e.set(A + "maxSdkVersion", str(max_sdk))
    return e


def has_action(e, n):
    return any(android_name(a) == n for f in e.findall("intent-filter") for a in f.findall("action"))


def ensure_action(e, n):
    if not has_action(e, n):
        f = ET.SubElement(e, "intent-filter")
        ET.SubElement(f, "action", {A + "name": n})


def component(app, tag, name):
    e = next((x for x in app.findall(tag) if android_name(x) == name), None)
    if e is None:
        e = ET.SubElement(app, tag, {A + "name": name})
    return e


def meta(parent, key, attr, value):
    m = next((x for x in parent.findall("meta-data") if android_name(x) == key), None)
    if m is None:
        m = ET.SubElement(parent, "meta-data", {A + "name": key})
    m.set(A + attr, value)
    return m


def verify_source_manifest(path):
    root = ET.parse(path).getroot()
    app = root.find("application")
    if app is None:
        raise RuntimeError("application yok")
    service = next((x for x in app.findall("service") if android_name(x) == "com.ryanheise.audioservice.AudioService"), None)
    if service is None or service.get(A + "foregroundServiceType") != "mediaPlayback":
        raise RuntimeError("AudioService yapılandırması hatalı")
    if not any(android_name(x) == "com.ryanheise.audioservice.MediaButtonReceiver" for x in app.findall("receiver")):
        raise RuntimeError("MediaButtonReceiver yok")
    if not any(android_name(x) == cls("MainActivity") for x in app.findall("activity")):
        raise RuntimeError("AudioServiceActivity yok")
    print("Kaynak AndroidManifest doğrulandı")


def configure_manifest(path):
    tree = ET.parse(path)
    root = tree.getroot()
    root.attrib.pop("package", None)
    # Google Analytics must not read the advertising ID (no ads; Play "Data
    # safety" stays simple). play-services-measurement merges AD_ID; drop it.
    for name in REMOVED_PERMISSIONS:
        e = next((x for x in root.findall("uses-permission") if android_name(x) == name), None)
        if e is None:
            e = ET.SubElement(root, "uses-permission", {A + "name": name})
        e.set(TOOLS + "node", "remove")
    for e in list(root.findall("uses-permission")):
        if android_name(e) == "android.permission.INTERNET":
            root.remove(e)
    for name, max_sdk in PERMISSIONS.items():
        ensure_permission(root, name, max_sdk)
    app = root.find("application")
    app.set(A + "label", LABEL)
    meta(app, "google_analytics_adid_collection_enabled", "value", "false")
    meta(app, "google_analytics_default_allow_ad_personalization_signals", "value", "false")
    # Android 10 only: read media by file path instead of photo_manager copying
    # every video into the cache first (ignored on Android 11+).
    app.set(A + "requestLegacyExternalStorage", "true")
    # Flutter 3.47.4's GLES Impeller backend can terminate the Linux x86_64
    # emulator (flutter/flutter#192736). Use the supported Skia fallback until
    # that engine regression is fixed, including in the APK exercised by CI.
    meta(app, "io.flutter.embedding.android.EnableImpeller", "value", "false")
    launcher = next((x for x in app.findall("activity") if has_action(x, "android.intent.action.MAIN")), None)
    if launcher is None:
        launcher = next((x for x in app.findall("activity")
                         if android_name(x) in (cls("MainActivity"), ".MainActivity", TEMPLATE_PKG + ".MainActivity")), None)
    if launcher is None:
        raise RuntimeError("Launcher yok")
    launcher.set(A + "name", cls("MainActivity"))
    launcher.set(A + "exported", "true")
    launcher.set(A + "launchMode", "singleTask")
    v = component(app, "activity", cls("VideoActivity"))
    for k, val in {"exported": "false", "supportsPictureInPicture": "true",
                   "configChanges": "orientation|screenSize|screenLayout|smallestScreenSize|keyboardHidden",
                   "theme": "@android:style/Theme.Material.NoActionBar"}.items():
        v.set(A + k, val)
    vs = component(app, "service", cls("VideoPlaybackService"))
    vs.set(A + "exported", "false")
    vs.set(A + "foregroundServiceType", "mediaPlayback")
    ensure_action(vs, "androidx.media3.session.MediaSessionService")
    # ACTION_VIEW is handled by our native media channel, not Flutter named routes.
    meta(launcher, "flutter_deeplinking_enabled", "value", "false")
    for f in list(launcher.findall("intent-filter")):
        if any(android_name(x) == "android.intent.action.VIEW" for x in f.findall("action")):
            launcher.remove(f)
    f = ET.SubElement(launcher, "intent-filter")
    ET.SubElement(f, "action", {A + "name": "android.intent.action.VIEW"})
    ET.SubElement(f, "category", {A + "name": "android.intent.category.DEFAULT"})
    for scheme in ["content", "file"]:
        ET.SubElement(f, "data", {A + "scheme": scheme})
    for mime in ["audio/*", "video/*", "application/ogg", "application/x-matroska"]:
        ET.SubElement(f, "data", {A + "mimeType": mime})
    s = component(app, "service", "com.ryanheise.audioservice.AudioService")
    s.set(A + "exported", "true")
    s.set(A + "enabled", "true")
    s.set(A + "foregroundServiceType", "mediaPlayback")
    ensure_action(s, "android.media.browse.MediaBrowserService")
    r = component(app, "receiver", "com.ryanheise.audioservice.MediaButtonReceiver")
    r.set(A + "exported", "true")
    r.set(A + "enabled", "true")
    ensure_action(r, "android.intent.action.MEDIA_BUTTON")
    w = component(app, "receiver", cls("MusicWidgetProvider"))
    w.set(A + "exported", "false")
    w.set(A + "label", LABEL)
    ensure_action(w, "android.appwidget.action.APPWIDGET_UPDATE")
    if not any(android_name(x) == "android.appwidget.provider" for x in w.findall("meta-data")):
        ET.SubElement(w, "meta-data", {A + "name": "android.appwidget.provider", A + "resource": "@xml/music_widget_info"})
    configure_push(app)
    configure_alarm(app)
    configure_updates(app)
    for f in list(launcher.findall("intent-filter")):
        if any(android_name(x) == "android.intent.action.MAIN" for x in f.findall("action")):
            launcher.remove(f)
    for color in ["Purple", "Blue", "Pink"]:
        alias = component(app, "activity-alias", cls("Icon" + color))
        alias.set(A + "targetActivity", cls("MainActivity"))
        alias.set(A + "exported", "true")
        alias.set(A + "enabled", "true" if color == "Purple" else "false")
        alias.set(A + "icon", "@drawable/icon_" + color.lower())
        alias.set(A + "label", LABEL)
        if not has_action(alias, "android.intent.action.MAIN"):
            f = ET.SubElement(alias, "intent-filter")
            ET.SubElement(f, "action", {A + "name": "android.intent.action.MAIN"})
            ET.SubElement(f, "category", {A + "name": "android.intent.category.LAUNCHER"})
    ET.indent(tree, space="    ")
    tree.write(path, encoding="utf-8", xml_declaration=True)
    verify_source_manifest(path)


AD_ID = "com.google.android.gms.permission.AD_ID"
# Merged in by play-services-measurement (Analytics); B Music shows no ads and
# does not need install-referrer or Privacy Sandbox attribution.
REMOVED_PERMISSIONS = (
    AD_ID,
    "android.permission.ACCESS_ADSERVICES_AD_ID",
    "android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
    "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
)
PUSH_SERVICE = cls("PushMessagingService")
PLUGIN_PUSH_SERVICE = "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"


def configure_push(app):
    """FCM messages go to our PushMessagingService (shared seen-ids with
    announcements.json); the firebase_messaging plugin's own service is removed so
    Android resolves MESSAGING_EVENT to exactly one service."""
    ps = component(app, "service", PUSH_SERVICE)
    ps.set(A + "exported", "false")
    ensure_action(ps, "com.google.firebase.MESSAGING_EVENT")
    rm = component(app, "service", PLUGIN_PUSH_SERVICE)
    rm.set(TOOLS + "node", "remove")
    meta(app, "com.google.firebase.messaging.default_notification_channel_id", "value", "announcements")
    meta(app, "com.google.firebase.messaging.default_notification_icon", "resource", "@drawable/ic_stat_bm")
    meta(app, "com.google.firebase.messaging.default_notification_color", "resource", "@color/bm_notification")


def configure_alarm(app):
    """Alarm music: exact AlarmManager alarm -> AlarmReceiver -> AlarmService
    (foreground, plays the chosen song) + full-screen AlarmActivity. BootReceiver
    re-arms saved alarms after a reboot, time change or app update."""
    receiver = component(app, "receiver", cls("AlarmReceiver"))
    receiver.set(A + "exported", "false")
    boot = component(app, "receiver", cls("AlarmBootReceiver"))
    boot.set(A + "exported", "true")
    for action in ("android.intent.action.BOOT_COMPLETED", "android.intent.action.MY_PACKAGE_REPLACED",
                   "android.intent.action.TIME_SET", "android.intent.action.TIMEZONE_CHANGED",
                   "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"):
        ensure_action(boot, action)
    service = component(app, "service", cls("AlarmService"))
    service.set(A + "exported", "false")
    service.set(A + "foregroundServiceType", "mediaPlayback")
    activity = component(app, "activity", cls("AlarmActivity"))
    for k, val in {"exported": "false", "showWhenLocked": "true", "turnScreenOn": "true",
                   "excludeFromRecents": "true", "launchMode": "singleInstance", "taskAffinity": "",
                   "theme": "@android:style/Theme.Material.NoActionBar",
                   "screenOrientation": "portrait"}.items():
        activity.set(A + k, val)


def configure_updates(app):
    """In-app update: the downloaded APK is handed to the system installer via a
    FileProvider (own subclass, so it never clashes with plugin providers)."""
    provider = component(app, "provider", cls("UpdateFileProvider"))
    provider.set(A + "authorities", PKG + ".updates")
    provider.set(A + "exported", "false")
    provider.set(A + "grantUriPermissions", "true")
    meta(provider, "android.support.FILE_PROVIDER_PATHS", "resource", "@xml/update_paths")


FIREBASE_KEYS = {"apiKey": "google_api_key", "appId": "google_app_id", "messagingSenderId": "gcm_defaultSenderId",
                 "projectId": "project_id", "storageBucket": "google_storage_bucket"}


def firebase_options(path=None):
    """Android FirebaseOptions from lib/firebase_options.dart ({} until configured)."""
    path = path or ROOT / "lib/firebase_options.dart"
    if not path.exists():
        return {}
    text = path.read_text()
    block = re.search(r"android\s*=\s*FirebaseOptions\((.*?)\);", text, re.S)
    if not block:
        return {}
    values = dict(re.findall(r"(\w+)\s*:\s*'([^']*)'", block.group(1)))
    return values if values.get("appId") and values.get("apiKey") else {}


def create_firebase_resources(res=None, options=None):
    """Same values FirebaseInitProvider would get from google-services.json, so
    the default FirebaseApp exists natively (pushes can start a stopped app)
    without the Gradle google-services plugin. Dart initialises with the same
    options from lib/firebase_options.dart."""
    res = res or ROOT / "android/app/src/main/res"
    options = firebase_options() if options is None else options
    target = res / "values/firebase_config.xml"
    if not options:
        target.unlink(missing_ok=True)
        print("Firebase yapılandırılmamış: anlık bildirimler kapalı")
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    rows = "".join(f'    <string name="{name}" translatable="false">{html.escape(options[key])}</string>\n'
                   for key, name in FIREBASE_KEYS.items() if options.get(key))
    target.write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" '
                      'tools:keep="@string/google_*,@string/gcm_defaultSenderId,@string/project_id">\n' + rows + '</resources>\n')
    print("Firebase Android yapılandırması yazıldı: " + options["projectId"])
    return True


def create_crashlytics_build_id(res=None, build_id=None):
    """Crashlytics refuses to start without a build id, which its Gradle plugin
    normally injects. We do not use that plugin (AGP 9 compatibility), so the
    same resource is written here — one fresh id per build."""
    res = res or ROOT / "android/app/src/main/res"
    target = res / "values/crashlytics_build_id.xml"
    target.parent.mkdir(parents=True, exist_ok=True)
    build_id = build_id or str(uuid.uuid4())
    target.write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" '
                      'tools:keep="@string/com.google.firebase.crashlytics.mapping_file_id">\n'
                      f'    <string name="com.google.firebase.crashlytics.mapping_file_id" translatable="false">{build_id}</string>\n'
                      '</resources>\n')
    return build_id


def firebase_bom_version(config_path):
    try:
        config = json.loads(config_path.read_text())
        uri = next(p for p in config["packages"] if p["name"] == "firebase_core")["rootUri"]
        root = Path(unquote(urlparse(uri).path)) if uri.startswith("file:") else (config_path.parent / unquote(uri)).resolve()
        return re.search(r"FirebaseSDKVersion=(\S+)", (root / "android/gradle.properties").read_text()).group(1)
    except Exception:
        return "34.19.0"


def configure_push_gradle(config_path, gradle=None):
    gradle = gradle or ROOT / "android/app/build.gradle.kts"
    text = gradle.read_text()
    if "// B_music02 push" in text:
        return
    bom = firebase_bom_version(config_path)
    gradle.write_text(text + '\n// B_music02 push\ndependencies {\n    implementation(platform("com.google.firebase:firebase-bom:'
                      + bom + '"))\n    implementation("com.google.firebase:firebase-messaging")\n'
                      '    implementation("com.google.firebase:firebase-analytics")\n}\n')


def configure_package(gradle=None):
    """com.example.b_music02 (flutter create template) -> com.bmusic.app, and a
    versionName that matches the release tag (v1.0.<build number>)."""
    gradle = gradle or ROOT / "android/app/build.gradle.kts"
    text = gradle.read_text()
    text = text.replace(f'namespace = "{TEMPLATE_PKG}"', f'namespace = "{PKG}"')
    text = text.replace(f'applicationId = "{TEMPLATE_PKG}"', f'applicationId = "{PKG}"')
    text = text.replace("versionName = flutter.versionName", 'versionName = "1.0." + flutter.versionCode')
    if f'applicationId = "{PKG}"' not in text or f'namespace = "{PKG}"' not in text:
        raise SystemExit("package rename: unexpected build.gradle.kts template")
    gradle.write_text(text)


def create_kotlin_sources():
    """All Kotlin sources live in tool/ with `package com.bmusic.app`."""
    base = ROOT / "android/app/src/main/kotlin"
    shutil.rmtree(base / "com/example", ignore_errors=True)
    target = base / PKG.replace(".", "/")
    target.mkdir(parents=True, exist_ok=True)
    sources = [ROOT / "tool/MainActivity.kt", *sorted((ROOT / "tool/android_video").glob("*.kt")),
               *sorted((ROOT / "tool/android_widgets").glob("*.kt"))]
    for source in sources:
        shutil.copyfile(source, target / source.name)
    tests_base = ROOT / "android/app/src/test/kotlin"
    shutil.rmtree(tests_base / "com/example", ignore_errors=True)
    tests = tests_base / PKG.replace(".", "/")
    tests.mkdir(parents=True, exist_ok=True)
    for source in (ROOT / "tool/android_test").glob("*.kt"):
        shutil.copyfile(source, tests / source.name)


def configure_dependencies(gradle=None):
    gradle = gradle or ROOT / "android/app/build.gradle.kts"
    text = gradle.read_text()
    if "// B_music02 video tools" in text:
        return
    media3 = "\n".join(f'    implementation("androidx.media3:media3-{name}:{MEDIA3}")'
                       for name in ["exoplayer", "ui", "session", "transformer"])
    gradle.write_text(text + "\n// B_music02 video tools\ndependencies {\n" + media3 + "\n"
                      f'    implementation("{FFMPEG_DECODER}")\n'
                      '    implementation("androidx.work:work-runtime:2.11.2")\n'
                      '    testImplementation("junit:junit:4.13.2")\n'
                      '    testImplementation("org.json:json:20240303")\n}\n')


def create_resources(res=None):
    res = res or ROOT / "android/app/src/main/res"
    # Player icons, the white BM notification silhouette (drawable-*dpi/ic_stat_bm.png)
    # and widget layouts.
    shutil.copytree(ROOT / "tool/android_video/res", res, dirs_exist_ok=True)
    shutil.copytree(ROOT / "tool/android_widgets/res", res, dirs_exist_ok=True)
    (res / "values").mkdir(parents=True, exist_ok=True)
    (res / "values/bmusic_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="bm_notification">{ACCENT}</color>\n'
        f'    <color name="bm_background">{BACKGROUND}</color>\n</resources>\n')
    # audio_service resolves its notification icons by names supplied from Dart;
    # the release resource shrinker cannot see those references. On Android 13+
    # a missing stop icon prevents PlaybackState.CustomAction from being built.
    raw = res / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    (raw / "keep.xml").write_text('<resources xmlns:tools="http://schemas.android.com/tools" '
                                  'tools:keep="@drawable/ic_stat_bm,@drawable/audio_service_*,@color/bm_notification" />')
    (res / "xml").mkdir(parents=True, exist_ok=True)
    (res / "xml/update_paths.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<paths>\n    <cache-path name="updates" path="updates/" />\n</paths>\n')
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    for name, color in {"purple": "#A53CFF", "blue": "#347BFF", "pink": "#FF4BB8"}.items():
        (drawable / f"icon_{name}.xml").write_text(
            '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item><shape android:shape="rectangle">'
            f'<solid android:color="{color}"/><corners android:radius="24dp"/></shape></item><item android:left="6dp" '
            'android:top="6dp" android:right="6dp" android:bottom="6dp" android:drawable="@mipmap/ic_launcher"/></layer-list>')
    configure_window_colors(res)


def configure_window_colors(res):
    """Dark launch screen and dark system navigation bar before Flutter draws
    (the template uses Theme.Light, i.e. a light grey bar with dark buttons)."""
    background = ('<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
                  '    <item android:drawable="@color/bm_background" />\n</layer-list>\n')
    for folder in ("drawable", "drawable-v21"):
        path = res / folder / "launch_background.xml"
        if path.exists():
            path.write_text(background)
    styles = ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
              '    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
              '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
              '        <item name="android:navigationBarColor">@color/bm_background</item>\n'
              '        <item name="android:statusBarColor">@color/bm_background</item>\n'
              '    </style>\n'
              '    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">\n'
              '        <item name="android:windowBackground">@color/bm_background</item>\n'
              '        <item name="android:navigationBarColor">@color/bm_background</item>\n'
              '        <item name="android:statusBarColor">@color/bm_background</item>\n'
              '    </style>\n</resources>\n')
    for folder in ("values", "values-night"):
        (res / folder).mkdir(parents=True, exist_ok=True)
        (res / folder / "styles.xml").write_text(styles)


def patch_audio_query(config_path):
    config = json.loads(config_path.read_text())
    pkg = next(p for p in config["packages"] if p["name"] == "on_audio_query_android")
    uri = pkg["rootUri"]
    root = Path(unquote(urlparse(uri).path)) if uri.startswith("file:") else (config_path.parent / unquote(uri)).resolve()
    gradle = root / "android/build.gradle"
    manifest = root / "android/src/main/AndroidManifest.xml"
    mt = ET.parse(manifest)
    mr = mt.getroot()
    package = mr.attrib.pop("package", None)
    text = gradle.read_text()
    if not re.search(r"\bnamespace\s*[= ]", text):
        text = re.sub(r"android\s*\{", 'android {\n    namespace "' + package + '"', text, count=1)
    text = re.sub(r"compileSdkVersion\s+\d+", "compileSdkVersion 36", text)
    if "// b_music02 JVM compatibility" not in text:
        text += ('\n// b_music02 JVM compatibility\nandroid {\n compileOptions { sourceCompatibility JavaVersion.VERSION_17; '
                 'targetCompatibility JavaVersion.VERSION_17 }\n kotlinOptions { jvmTarget = "17" }\n}\n')
    gradle.write_text(text)
    mt.write(manifest, encoding="utf-8", xml_declaration=True)


PATCHES = [
  [
    "            player = builder.build();\n            player.setTrackSelectionParameters(",
    "            player = builder.build();\n            // B_music02: initialise the effect session before Dart reads its parameters.\n            if (!rawAudioEffects.isEmpty()\n                    && player.getAudioSessionId() == C.AUDIO_SESSION_ID_UNSET) {\n                int effectSessionId = Util.generateAudioSessionIdV21(context);\n                if (effectSessionId != C.AUDIO_SESSION_ID_UNSET) {\n                    player.setAudioSessionId(effectSessionId);\n                }\n            }\n            player.setTrackSelectionParameters("
  ],
  [
    "                AudioEffect audioEffect = decodeAudioEffect(rawAudioEffect, this.audioSessionId);\n                if ((Boolean)json.get(\"enabled\")) {\n                    audioEffect.setEnabled(true);\n                }\n                audioEffects.add(audioEffect);\n                audioEffectsMap.put((String)json.get(\"type\"), audioEffect);",
    "                AudioEffect audioEffect = null;\n                try {\n                    audioEffect = decodeAudioEffect(rawAudioEffect, this.audioSessionId);\n                    if ((Boolean)json.get(\"enabled\")) {\n                        audioEffect.setEnabled(true);\n                    }\n                    audioEffects.add(audioEffect);\n                    audioEffectsMap.put((String)json.get(\"type\"), audioEffect);\n                } catch (RuntimeException error) {\n                    if (audioEffect != null) audioEffect.release();\n                    android.util.Log.w(\"just_audio\",\n                            \"Optional audio effect unavailable: \" + json.get(\"type\"));\n                }"
  ],
  [
    "        Equalizer equalizer = (Equalizer)audioEffectsMap.get(\"AndroidEqualizer\");\n        ArrayList<Object> rawBands = new ArrayList<>();",
    "        Equalizer equalizer = (Equalizer)audioEffectsMap.get(\"AndroidEqualizer\");\n        ArrayList<Object> rawBands = new ArrayList<>();\n        if (equalizer == null) {\n            return mapOf(\"parameters\", mapOf(\n                    \"minDecibels\", 0.0, \"maxDecibels\", 0.0, \"bands\", rawBands));\n        }"
  ],
  [
    "        audioEffectsMap.get(type).setEnabled(enabled);",
    "        AudioEffect effect = audioEffectsMap.get(type);\n        if (effect != null) effect.setEnabled(enabled);"
  ],
  [
    "        ((Equalizer)audioEffectsMap.get(\"AndroidEqualizer\")).setBandLevel((short)bandIndex, (short)(Math.round(gain * 100.0)));",
    "        Equalizer equalizer = (Equalizer)audioEffectsMap.get(\"AndroidEqualizer\");\n        if (equalizer != null) {\n            equalizer.setBandLevel((short)bandIndex, (short)(Math.round(gain * 100.0)));\n        }"
  ]
]
MARKER = "// B_music02: initialise the effect session"

def patch_audio_effects(config_path: Path) -> None:
    config = json.loads(config_path.read_text())
    package = next(p for p in config["packages"] if p["name"] == "just_audio")
    uri = package["rootUri"]
    root = (Path(unquote(urlparse(uri).path)) if uri.startswith("file:")
            else (config_path.parent / unquote(uri)).resolve())
    source = root / "android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java"
    text = source.read_text()
    if MARKER in text:
        return
    # Fail on an upstream change instead of silently applying a partial patch.
    for before, after in PATCHES:
        if text.count(before) != 1:
            raise RuntimeError("just_audio audio-effect source changed; review its Android patch")
        text = text.replace(before, after, 1)
    source.write_text(text)
    print("Android audio-effect session and optional equalizer fallback configured")

SIGNING_MARKER = "// B_music02 release signing"


def configure_signing(gradle=None):
    """Sign release APKs with the persistent B Music key when CI provides it.

    Flutter's template signs release builds with the runner's freshly generated
    debug key, so every build had a different certificate and Android refused to
    update an installed copy. BMUSIC_KEYSTORE_PATH etc. come from repo secrets."""
    gradle = gradle or ROOT / "android/app/build.gradle.kts"
    text = gradle.read_text()
    if SIGNING_MARKER in text:
        return
    block = ("    " + SIGNING_MARKER + "\n    signingConfigs {\n"
             "        val bmusicStore = System.getenv(\"BMUSIC_KEYSTORE_PATH\")\n"
             "        if (!bmusicStore.isNullOrEmpty()) {\n"
             "            create(\"bmusicRelease\") {\n"
             "                storeFile = file(bmusicStore)\n"
             "                storePassword = System.getenv(\"BMUSIC_KEYSTORE_PASSWORD\")\n"
             "                keyAlias = System.getenv(\"BMUSIC_KEY_ALIAS\")\n"
             "                keyPassword = System.getenv(\"BMUSIC_KEY_PASSWORD\")\n"
             "            }\n        }\n    }\n\n")
    old = 'signingConfig = signingConfigs.getByName("debug")'
    if "    buildTypes {" not in text or old not in text:
        raise SystemExit("release signing: unexpected build.gradle.kts template")
    text = text.replace("    buildTypes {", block + "    buildTypes {", 1)
    text = text.replace(old, 'signingConfig = signingConfigs.findByName("bmusicRelease") ?: signingConfigs.getByName("debug")', 1)
    gradle.write_text(text)


def main():
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    config = ROOT / ".dart_tool/package_config.json"
    configure_manifest(manifest)
    configure_package()
    configure_signing()
    create_kotlin_sources()
    configure_dependencies()
    create_resources()
    patch_audio_query(config)
    patch_audio_effects(config)
    configure_push_gradle(config)
    create_firebase_resources()
    create_crashlytics_build_id()
    verify_source_manifest(manifest)
    print("B Music Android yapılandırması tamamlandı (" + PKG + ").")


if __name__ == "__main__":
    main()
