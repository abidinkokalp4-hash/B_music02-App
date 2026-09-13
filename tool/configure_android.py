"""Configure Android for B_music02 local music/background playback."""

from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]

ANDROID_NS = "http://schemas.android.com/apk/res/android"
A = f"{{{ANDROID_NS}}}"

ET.register_namespace("android", ANDROID_NS)


def android_name(element):
    return element.get(A + "name")


def ensure_permission(root, name, max_sdk=None):
    full_name = f"android.permission.{name}"

    element = next(
        (
            item
            for item in root.findall("uses-permission")
            if android_name(item) == full_name
        ),
        None,
    )

    if element is None:
        element = ET.SubElement(
            root,
            "uses-permission",
            {A + "name": full_name},
        )

    if max_sdk is not None:
        element.set(A + "maxSdkVersion", str(max_sdk))


def has_action(element, action_name):
    for intent_filter in element.findall("intent-filter"):
        for action in intent_filter.findall("action"):
            if android_name(action) == action_name:
                return True
    return False


def ensure_action(element, action_name):
    if has_action(element, action_name):
        return

    intent_filter = ET.SubElement(element, "intent-filter")
    ET.SubElement(
        intent_filter,
        "action",
        {A + "name": action_name},
    )


def verify_source_manifest(path: Path):
    tree = ET.parse(path)
    root = tree.getroot()

    app = root.find("application")
    if app is None:
        raise RuntimeError("AndroidManifest.xml application elementi bulunamadı.")

    service = next(
        (
            item
            for item in app.findall("service")
            if android_name(item)
            == "com.ryanheise.audioservice.AudioService"
        ),
        None,
    )

    if service is None:
        raise RuntimeError(
            "AudioService kaynak AndroidManifest.xml içine eklenemedi."
        )

    if service.get(A + "foregroundServiceType") != "mediaPlayback":
        raise RuntimeError(
            "AudioService foregroundServiceType=mediaPlayback değil."
        )

    receiver = next(
        (
            item
            for item in app.findall("receiver")
            if android_name(item)
            == "com.ryanheise.audioservice.MediaButtonReceiver"
        ),
        None,
    )

    if receiver is None:
        raise RuntimeError(
            "MediaButtonReceiver kaynak AndroidManifest.xml içine eklenemedi."
        )

    activities = app.findall("activity")

    if not any(
        android_name(activity)
        == "com.ryanheise.audioservice.AudioServiceActivity"
        for activity in activities
    ):
        raise RuntimeError(
            "AudioServiceActivity kaynak AndroidManifest.xml içinde bulunamadı."
        )

    print("Kaynak AndroidManifest doğrulandı:")
    print("  ✓ AudioService")
    print("  ✓ MediaButtonReceiver")
    print("  ✓ AudioServiceActivity")
    print("  ✓ foregroundServiceType=mediaPlayback")


def configure_manifest(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Manifest bulunamadı: {path}")

    tree = ET.parse(path)
    root = tree.getroot()

    permissions = {
        "INTERNET": None,
        "WAKE_LOCK": None,
        "FOREGROUND_SERVICE": None,
        "FOREGROUND_SERVICE_MEDIA_PLAYBACK": None,
        "READ_MEDIA_AUDIO": None,
        "READ_EXTERNAL_STORAGE": 32,
        "POST_NOTIFICATIONS": None,
    }

    for permission, max_sdk in permissions.items():
        ensure_permission(
            root,
            permission,
            max_sdk=max_sdk,
        )

    app = root.find("application")

    if app is None:
        raise RuntimeError("Android application elementi bulunamadı.")

    app.set(A + "label", "B_music02")

    launcher_activity = None

    for activity in app.findall("activity"):
        if has_action(activity, "android.intent.action.MAIN"):
            launcher_activity = activity
            break

    if launcher_activity is None:
        raise RuntimeError(
            "Launcher/MainActivity AndroidManifest.xml içinde bulunamadı."
        )

    # audio_service kendi Activity sınıfını kullanmalıdır.
    launcher_activity.set(
        A + "name",
        "com.ryanheise.audioservice.AudioServiceActivity",
    )
    launcher_activity.set(A + "exported", "true")

    # Background playback servisi.
    service_name = "com.ryanheise.audioservice.AudioService"

    service = next(
        (
            item
            for item in app.findall("service")
            if android_name(item) == service_name
        ),
        None,
    )

    if service is None:
        service = ET.SubElement(
            app,
            "service",
            {A + "name": service_name},
        )

    service.set(A + "exported", "true")
    service.set(A + "enabled", "true")
    service.set(A + "foregroundServiceType", "mediaPlayback")

    ensure_action(
        service,
        "android.media.browse.MediaBrowserService",
    )

    # Kulaklık/Bluetooth/bildirim medya butonları.
    receiver_name = "com.ryanheise.audioservice.MediaButtonReceiver"

    receiver = next(
        (
            item
            for item in app.findall("receiver")
            if android_name(item) == receiver_name
        ),
        None,
    )

    if receiver is None:
        receiver = ET.SubElement(
            app,
            "receiver",
            {A + "name": receiver_name},
        )

    receiver.set(A + "exported", "true")
    receiver.set(A + "enabled", "true")

    ensure_action(
        receiver,
        "android.intent.action.MEDIA_BUTTON",
    )

    ET.indent(tree, space="    ")

    tree.write(
        path,
        encoding="utf-8",
        xml_declaration=True,
    )

    # Yazdıktan sonra tekrar okuyup gerçekten eklendiğini doğrula.
    verify_source_manifest(path)


def patch_audio_query(config_path: Path):
    if not config_path.exists():
        raise FileNotFoundError(
            f"Flutter package config bulunamadı: {config_path}"
        )

    config = json.loads(config_path.read_text(encoding="utf-8"))

    package = next(
        (
            package
            for package in config["packages"]
            if package["name"] == "on_audio_query_android"
        ),
        None,
    )

    if package is None:
        raise RuntimeError(
            "on_audio_query_android package_config içinde bulunamadı."
        )

    uri = package["rootUri"]

    if uri.startswith("file:"):
        package_root = Path(
            unquote(urlparse(uri).path)
        )
    else:
        package_root = (
            config_path.parent / unquote(uri)
        ).resolve()

    gradle = package_root / "android/build.gradle"
    manifest = package_root / "android/src/main/AndroidManifest.xml"

    if not gradle.exists():
        raise FileNotFoundError(
            f"on_audio_query Android Gradle dosyası bulunamadı: {gradle}"
        )

    if not manifest.exists():
        raise FileNotFoundError(
            f"on_audio_query AndroidManifest bulunamadı: {manifest}"
        )

    manifest_tree = ET.parse(manifest)
    manifest_root = manifest_tree.getroot()

    package_name = manifest_root.attrib.pop("package", None)

    gradle_text = gradle.read_text(encoding="utf-8")

    # Eski on_audio_query_android sürümünü AGP 8+ ile uyumlu hale getir.
    if not re.search(r"\bnamespace\s*[= ]", gradle_text):
        if not package_name:
            raise RuntimeError(
                "on_audio_query_android namespace belirlenemedi."
            )

        gradle_text = re.sub(
            r"android\s*\{",
            'android {\n    namespace "' + package_name + '"',
            gradle_text,
            count=1,
        )

    gradle_text = re.sub(
        r"compileSdkVersion\s+\d+",
        "compileSdkVersion 36",
        gradle_text,
    )

    marker = "// b_music02 JVM compatibility"

    if marker not in gradle_text:
        gradle_text += f"""

{marker}
android {{
    compileOptions {{
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }}

    kotlinOptions {{
        jvmTarget = "17"
    }}
}}
"""

    gradle.write_text(
        gradle_text,
        encoding="utf-8",
    )

    # AGP 8 library manifestinde package attribute istemiyor.
    manifest_tree.write(
        manifest,
        encoding="utf-8",
        xml_declaration=True,
    )

    print("on_audio_query_android Android 36 / Java 17 için yapılandırıldı.")


def create_notification_icon():
    drawable = ROOT / "android/app/src/main/res/drawable"
    drawable.mkdir(parents=True, exist_ok=True)

    icon = drawable / "ic_stat_music.xml"

    icon.write_text(
        """<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,3v10.55A4,4 0,1 0,14 17V7h4V3z" />
</vector>
""",
        encoding="utf-8",
    )

    raw = ROOT / "android/app/src/main/res/raw"
    raw.mkdir(parents=True, exist_ok=True)

    keep = raw / "keep.xml"

    keep.write_text(
        """<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_music" />
""",
        encoding="utf-8",
    )


def main():
    manifest = (
        ROOT
        / "android"
        / "app"
        / "src"
        / "main"
        / "AndroidManifest.xml"
    )

    print(f"Android manifest yapılandırılıyor: {manifest}")

    configure_manifest(manifest)
    create_notification_icon()

    patch_audio_query(
        ROOT / ".dart_tool/package_config.json"
    )

    # Plugin patch işleminden sonra manifesti bir kez daha doğrula.
    verify_source_manifest(manifest)

    print("")
    print("B_music02 Android yapılandırması tamamlandı.")


if __name__ == "__main__":
    main()
