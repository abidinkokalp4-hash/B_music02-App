"""Configure Android for B_music02 local media/background playback."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse
ROOT=Path(__file__).resolve().parents[1]
ANDROID_NS="http://schemas.android.com/apk/res/android"; A=f"{{{ANDROID_NS}}}"; ET.register_namespace("android",ANDROID_NS)
def android_name(e): return e.get(A+"name")
def ensure_permission(root,name,max_sdk=None):
 full=f"android.permission.{name}"; e=next((x for x in root.findall("uses-permission") if android_name(x)==full),None)
 if e is None: e=ET.SubElement(root,"uses-permission",{A+"name":full})
 if max_sdk is not None:e.set(A+"maxSdkVersion",str(max_sdk))
def has_action(e,n): return any(android_name(a)==n for f in e.findall("intent-filter") for a in f.findall("action"))
def ensure_action(e,n):
 if not has_action(e,n):
  f=ET.SubElement(e,"intent-filter");ET.SubElement(f,"action",{A+"name":n})
def verify_source_manifest(path):
 root=ET.parse(path).getroot();app=root.find("application")
 if app is None:raise RuntimeError("application yok")
 service=next((x for x in app.findall("service") if android_name(x)=="com.ryanheise.audioservice.AudioService"),None)
 if service is None or service.get(A+"foregroundServiceType")!="mediaPlayback":raise RuntimeError("AudioService yapılandırması hatalı")
 if not any(android_name(x)=="com.ryanheise.audioservice.MediaButtonReceiver" for x in app.findall("receiver")):raise RuntimeError("MediaButtonReceiver yok")
 if not any(android_name(x)=="com.example.b_music02.MainActivity" for x in app.findall("activity")):raise RuntimeError("AudioServiceActivity yok")
 print("Kaynak AndroidManifest doğrulandı")
def configure_manifest(path):
 tree=ET.parse(path);root=tree.getroot()
 for e in list(root.findall("uses-permission")):
  if android_name(e)=="android.permission.INTERNET":root.remove(e)
 ET.register_namespace("tools","http://schemas.android.com/tools")
 for p,m in {"WAKE_LOCK":None,"FOREGROUND_SERVICE":None,"FOREGROUND_SERVICE_MEDIA_PLAYBACK":None,"READ_MEDIA_AUDIO":None,"READ_MEDIA_VIDEO":None,"READ_EXTERNAL_STORAGE":32,"WRITE_EXTERNAL_STORAGE":28,"POST_NOTIFICATIONS":None}.items():ensure_permission(root,p,m)
 ensure_permission(root,"INTERNET")
 app=root.find("application");app.set(A+"label","B_music02")
 # Flutter 3.47.4's GLES Impeller backend can terminate the Linux x86_64
 # emulator (flutter/flutter#192736). Use the supported Skia fallback until
 # that engine regression is fixed, including in the APK exercised by CI.
 renderer=next((x for x in app.findall("meta-data") if android_name(x)=="io.flutter.embedding.android.EnableImpeller"),None)
 if renderer is None:renderer=ET.SubElement(app,"meta-data",{A+"name":"io.flutter.embedding.android.EnableImpeller"})
 renderer.set(A+"value","false")
 launcher=next((x for x in app.findall("activity") if has_action(x,"android.intent.action.MAIN")),None)
 if launcher is None:launcher=next((x for x in app.findall("activity") if android_name(x)=="com.example.b_music02.MainActivity"),None)
 if launcher is None:raise RuntimeError("Launcher yok")
 launcher.set(A+"name","com.example.b_music02.MainActivity");launcher.set(A+"exported","true")
 v=next((x for x in app.findall("activity") if android_name(x)=="com.example.b_music02.VideoActivity"),None)
 if v is None:v=ET.SubElement(app,"activity",{A+"name":"com.example.b_music02.VideoActivity"})
 for k,val in {"exported":"false","supportsPictureInPicture":"true","configChanges":"orientation|screenSize|screenLayout|smallestScreenSize|keyboardHidden","theme":"@android:style/Theme.Material.NoActionBar"}.items():v.set(A+k,val)
 vs=next((x for x in app.findall("service") if android_name(x)=="com.example.b_music02.VideoPlaybackService"),None)
 if vs is None:vs=ET.SubElement(app,"service",{A+"name":"com.example.b_music02.VideoPlaybackService"})
 vs.set(A+"exported","false");vs.set(A+"foregroundServiceType","mediaPlayback");ensure_action(vs,"androidx.media3.session.MediaSessionService")
 launcher.set(A+"launchMode","singleTask")
 # ACTION_VIEW is handled by our native media channel, not Flutter named routes.
 deep=next((x for x in launcher.findall("meta-data") if android_name(x)=="flutter_deeplinking_enabled"),None)
 if deep is None:deep=ET.SubElement(launcher,"meta-data",{A+"name":"flutter_deeplinking_enabled"})
 deep.set(A+"value","false")
 for f in list(launcher.findall("intent-filter")):
  if any(android_name(x)=="android.intent.action.VIEW" for x in f.findall("action")):launcher.remove(f)
 f=ET.SubElement(launcher,"intent-filter")
 ET.SubElement(f,"action",{A+"name":"android.intent.action.VIEW"})
 ET.SubElement(f,"category",{A+"name":"android.intent.category.DEFAULT"})
 for scheme in ["content","file"]:ET.SubElement(f,"data",{A+"scheme":scheme})
 for mime in ["audio/*","video/*","application/ogg","application/x-matroska"]:ET.SubElement(f,"data",{A+"mimeType":mime})
 s=next((x for x in app.findall("service") if android_name(x)=="com.ryanheise.audioservice.AudioService"),None)
 if s is None:s=ET.SubElement(app,"service",{A+"name":"com.ryanheise.audioservice.AudioService"})
 s.set(A+"exported","true");s.set(A+"enabled","true");s.set(A+"foregroundServiceType","mediaPlayback");ensure_action(s,"android.media.browse.MediaBrowserService")
 r=next((x for x in app.findall("receiver") if android_name(x)=="com.ryanheise.audioservice.MediaButtonReceiver"),None)
 if r is None:r=ET.SubElement(app,"receiver",{A+"name":"com.ryanheise.audioservice.MediaButtonReceiver"})
 r.set(A+"exported","true");r.set(A+"enabled","true");ensure_action(r,"android.intent.action.MEDIA_BUTTON")
 w=next((x for x in app.findall("receiver") if android_name(x)=="com.example.b_music02.MusicWidgetProvider"),None)
 if w is None:w=ET.SubElement(app,"receiver",{A+"name":"com.example.b_music02.MusicWidgetProvider"})
 w.set(A+"exported","false");w.set(A+"label","B_music02");ensure_action(w,"android.appwidget.action.APPWIDGET_UPDATE")
 if not any(android_name(x)=="android.appwidget.provider" for x in w.findall("meta-data")):
  ET.SubElement(w,"meta-data",{A+"name":"android.appwidget.provider",A+"resource":"@xml/music_widget_info"})
 configure_push(app)
 for f in list(launcher.findall("intent-filter")):
  if any(android_name(x)=="android.intent.action.MAIN" for x in f.findall("action")):launcher.remove(f)
 for color in ["Purple","Blue","Pink"]:
  name="com.example.b_music02.Icon"+color
  alias=next((x for x in app.findall("activity-alias") if android_name(x)==name),None)
  if alias is None:alias=ET.SubElement(app,"activity-alias",{A+"name":name})
  alias.set(A+"targetActivity","com.example.b_music02.MainActivity");alias.set(A+"exported","true");alias.set(A+"enabled","true" if color=="Purple" else "false");alias.set(A+"icon","@drawable/icon_"+color.lower());alias.set(A+"label","B_music02")
  if not has_action(alias,"android.intent.action.MAIN"):
   f=ET.SubElement(alias,"intent-filter");ET.SubElement(f,"action",{A+"name":"android.intent.action.MAIN"});ET.SubElement(f,"category",{A+"name":"android.intent.category.LAUNCHER"})
 ET.indent(tree,space="    ");tree.write(path,encoding="utf-8",xml_declaration=True);verify_source_manifest(path)
TOOLS="{http://schemas.android.com/tools}"
PUSH_SERVICE="com.example.b_music02.PushMessagingService"
PLUGIN_PUSH_SERVICE="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
def configure_push(app):
 """FCM messages go to our PushMessagingService (shared seen-ids with
 announcements.json); the firebase_messaging plugin's own service is removed so
 Android resolves MESSAGING_EVENT to exactly one service."""
 ps=next((x for x in app.findall("service") if android_name(x)==PUSH_SERVICE),None)
 if ps is None:ps=ET.SubElement(app,"service",{A+"name":PUSH_SERVICE})
 ps.set(A+"exported","false");ensure_action(ps,"com.google.firebase.MESSAGING_EVENT")
 rm=next((x for x in app.findall("service") if android_name(x)==PLUGIN_PUSH_SERVICE),None)
 if rm is None:rm=ET.SubElement(app,"service",{A+"name":PLUGIN_PUSH_SERVICE})
 rm.set(TOOLS+"node","remove")
 for key,attr,value in (("com.google.firebase.messaging.default_notification_channel_id","value","announcements"),
                        ("com.google.firebase.messaging.default_notification_icon","resource","@drawable/ic_stat_music")):
  m=next((x for x in app.findall("meta-data") if android_name(x)==key),None)
  if m is None:m=ET.SubElement(app,"meta-data",{A+"name":key})
  m.set(A+attr,value)

FIREBASE_KEYS={"apiKey":"google_api_key","appId":"google_app_id","messagingSenderId":"gcm_defaultSenderId","projectId":"project_id","storageBucket":"google_storage_bucket"}
def firebase_options(path=None):
 """Android FirebaseOptions from lib/firebase_options.dart ({} until configured)."""
 path=path or ROOT/"lib/firebase_options.dart"
 if not path.exists():return {}
 text=path.read_text();block=re.search(r"android\s*=\s*FirebaseOptions\((.*?)\);",text,re.S)
 if not block:return {}
 values=dict(re.findall(r"(\w+)\s*:\s*'([^']*)'",block.group(1)))
 return values if values.get("appId") and values.get("apiKey") else {}
def create_firebase_resources(res=None,options=None):
 """Same values FirebaseInitProvider would get from google-services.json, so
 the default FirebaseApp exists natively (pushes can start a stopped app)
 without the Gradle google-services plugin. Dart initialises with the same
 options from lib/firebase_options.dart."""
 res=res or ROOT/"android/app/src/main/res";options=firebase_options() if options is None else options
 target=res/"values/firebase_config.xml"
 if not options:
  target.unlink(missing_ok=True);print("Firebase yapılandırılmamış: anlık bildirimler kapalı");return False
 import html
 target.parent.mkdir(parents=True,exist_ok=True)
 rows="".join(f'    <string name="{name}" translatable="false">{html.escape(options[key])}</string>\n' for key,name in FIREBASE_KEYS.items() if options.get(key))
 target.write_text('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@string/google_*,@string/gcm_defaultSenderId,@string/project_id">\n'+rows+'</resources>\n')
 print("Firebase Android yapılandırması yazıldı: "+options["projectId"]);return True
def firebase_bom_version(config_path):
 try:
  config=json.loads(config_path.read_text());uri=next(p for p in config["packages"] if p["name"]=="firebase_core")["rootUri"]
  root=Path(unquote(urlparse(uri).path)) if uri.startswith("file:") else (config_path.parent/unquote(uri)).resolve()
  return re.search(r"FirebaseSDKVersion=(\S+)",(root/"android/gradle.properties").read_text()).group(1)
 except Exception:return "34.19.0"
def configure_push_gradle(config_path,gradle=None):
 gradle=gradle or ROOT/"android/app/build.gradle.kts";text=gradle.read_text()
 if "// B_music02 push" in text:return
 bom=firebase_bom_version(config_path)
 gradle.write_text(text+'\n// B_music02 push\ndependencies {\n    implementation(platform("com.google.firebase:firebase-bom:'+bom+'"))\n    implementation("com.google.firebase:firebase-messaging")\n}\n')

def patch_audio_query(config_path):
 config=json.loads(config_path.read_text());pkg=next(p for p in config["packages"] if p["name"]=="on_audio_query_android");uri=pkg["rootUri"]
 root=Path(unquote(urlparse(uri).path)) if uri.startswith("file:") else (config_path.parent/unquote(uri)).resolve();gradle=root/"android/build.gradle";manifest=root/"android/src/main/AndroidManifest.xml"
 mt=ET.parse(manifest);mr=mt.getroot();package=mr.attrib.pop("package",None);text=gradle.read_text()
 if not re.search(r"\bnamespace\s*[= ]",text):text=re.sub(r"android\s*\{",'android {\n    namespace "'+package+'"',text,count=1)
 text=re.sub(r"compileSdkVersion\s+\d+","compileSdkVersion 36",text)
 if "// b_music02 JVM compatibility" not in text:text+='\n// b_music02 JVM compatibility\nandroid {\n compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }\n kotlinOptions { jvmTarget = "17" }\n}\n'
 gradle.write_text(text);mt.write(manifest,encoding="utf-8",xml_declaration=True)
def create_notification_icon():
 d=ROOT/"android/app/src/main/res/drawable";d.mkdir(parents=True,exist_ok=True);(d/"ic_stat_music.xml").write_text('<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M12,3v10.55A4,4 0,1 0,14 17V7h4V3z" /></vector>')
 # audio_service resolves its control icons by names supplied from Dart. The
 # release resource shrinker cannot see those references. On Android 13+, a
 # missing stop icon prevents PlaybackState.CustomAction from being built and
 # the MediaSession never enters its playing/foreground state.
 raw=ROOT/"android/app/src/main/res/raw";raw.mkdir(parents=True,exist_ok=True);(raw/"keep.xml").write_text('<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_music,@drawable/audio_service_*" />')
def create_launcher_icons():
 d=ROOT/"android/app/src/main/res/drawable";d.mkdir(parents=True,exist_ok=True)
 for name,color in {"purple":"#A53CFF","blue":"#347BFF","pink":"#FF4BB8"}.items():
  (d/("icon_"+name+".xml")).write_text('<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item><shape android:shape="rectangle"><solid android:color="'+color+'"/><corners android:radius="24dp"/></shape></item><item android:left="6dp" android:top="6dp" android:right="6dp" android:bottom="6dp" android:drawable="@mipmap/ic_launcher"/></layer-list>')
def create_activity():
 p=ROOT/"android/app/src/main/kotlin/com/example/b_music02/MainActivity.kt";p.parent.mkdir(parents=True,exist_ok=True);p.write_text((ROOT/"tool/MainActivity.kt").read_text())
def create_video_platform():
 import shutil
 target=ROOT/"android/app/src/main/kotlin/com/example/b_music02"
 for source in (ROOT/"tool/android_video").glob("*.kt"):shutil.copyfile(source,target/source.name)
 # Material vector icons used by the native player controls and PiP actions.
 shutil.copytree(ROOT/"tool/android_video/res",ROOT/"android/app/src/main/res",dirs_exist_ok=True)
 gradle=ROOT/"android/app/build.gradle.kts"
 dependencies='\n// B_music02 video tools\ndependencies {\n'+'\n'.join('    implementation("androidx.media3:media3-'+name+':1.11.1")' for name in ['exoplayer','ui','session','transformer'])+'\n    implementation("androidx.work:work-runtime:2.11.2")\n    testImplementation("junit:junit:4.13.2")\n    testImplementation("org.json:json:20240303")\n}\n'
 text=gradle.read_text()
 if '// B_music02 video tools' not in text:gradle.write_text(text+dependencies)
 # JVM unit tests for pure Kotlin logic (run with ./gradlew :app:testReleaseUnitTest).
 tests=ROOT/"android/app/src/test/kotlin/com/example/b_music02";tests.mkdir(parents=True,exist_ok=True)
 for source in (ROOT/"tool/android_test").glob("*.kt"):shutil.copyfile(source,tests/source.name)

def create_widgets():
 import shutil
 source=ROOT/"tool/android_widgets"
 target=ROOT/"android/app/src/main/kotlin/com/example/b_music02/MusicWidgetProvider.kt"
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/"MusicWidgetProvider.kt",target)
 shutil.copytree(source/"res",ROOT/"android/app/src/main/res",dirs_exist_ok=True)
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
 gradle=gradle or ROOT/"android/app/build.gradle.kts"
 text=gradle.read_text()
 if SIGNING_MARKER in text:return
 block=("    "+SIGNING_MARKER+"\n    signingConfigs {\n"
  "        val bmusicStore = System.getenv(\"BMUSIC_KEYSTORE_PATH\")\n"
  "        if (!bmusicStore.isNullOrEmpty()) {\n"
  "            create(\"bmusicRelease\") {\n"
  "                storeFile = file(bmusicStore)\n"
  "                storePassword = System.getenv(\"BMUSIC_KEYSTORE_PASSWORD\")\n"
  "                keyAlias = System.getenv(\"BMUSIC_KEY_ALIAS\")\n"
  "                keyPassword = System.getenv(\"BMUSIC_KEY_PASSWORD\")\n"
  "            }\n        }\n    }\n\n")
 old='signingConfig = signingConfigs.getByName("debug")'
 if "    buildTypes {" not in text or old not in text:raise SystemExit("release signing: unexpected build.gradle.kts template")
 text=text.replace("    buildTypes {",block+"    buildTypes {",1)
 text=text.replace(old,'signingConfig = signingConfigs.findByName("bmusicRelease") ?: signingConfigs.getByName("debug")',1)
 gradle.write_text(text)

def main():
 manifest=ROOT/"android/app/src/main/AndroidManifest.xml";configure_manifest(manifest);configure_signing();create_activity();create_video_platform();create_widgets();create_notification_icon();create_launcher_icons();patch_audio_query(ROOT/".dart_tool/package_config.json");patch_audio_effects(ROOT/".dart_tool/package_config.json");configure_push_gradle(ROOT/".dart_tool/package_config.json");create_firebase_resources();verify_source_manifest(manifest);print("B_music02 Android yapılandırması tamamlandı.")
if __name__=="__main__":main()
