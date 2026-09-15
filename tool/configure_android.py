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
 for p,m in {"INTERNET":None,"WAKE_LOCK":None,"FOREGROUND_SERVICE":None,"FOREGROUND_SERVICE_MEDIA_PLAYBACK":None,"READ_MEDIA_AUDIO":None,"READ_MEDIA_VIDEO":None,"READ_EXTERNAL_STORAGE":32,"POST_NOTIFICATIONS":None}.items():ensure_permission(root,p,m)
 app=root.find("application");app.set(A+"label","B_music02")
 launcher=next((x for x in app.findall("activity") if has_action(x,"android.intent.action.MAIN")),None)
 if launcher is None:launcher=next((x for x in app.findall("activity") if android_name(x)=="com.example.b_music02.MainActivity"),None)
 if launcher is None:raise RuntimeError("Launcher yok")
 launcher.set(A+"name","com.example.b_music02.MainActivity");launcher.set(A+"exported","true")
 s=next((x for x in app.findall("service") if android_name(x)=="com.ryanheise.audioservice.AudioService"),None) or ET.SubElement(app,"service",{A+"name":"com.ryanheise.audioservice.AudioService"})
 s.set(A+"exported","true");s.set(A+"enabled","true");s.set(A+"foregroundServiceType","mediaPlayback");ensure_action(s,"android.media.browse.MediaBrowserService")
 r=next((x for x in app.findall("receiver") if android_name(x)=="com.ryanheise.audioservice.MediaButtonReceiver"),None) or ET.SubElement(app,"receiver",{A+"name":"com.ryanheise.audioservice.MediaButtonReceiver"})
 r.set(A+"exported","true");r.set(A+"enabled","true");ensure_action(r,"android.intent.action.MEDIA_BUTTON")
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
 raw=ROOT/"android/app/src/main/res/raw";raw.mkdir(parents=True,exist_ok=True);(raw/"keep.xml").write_text('<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_music" />')
def create_launcher_icons():
 d=ROOT/"android/app/src/main/res/drawable";d.mkdir(parents=True,exist_ok=True)
 for name,color in {"purple":"#A53CFF","blue":"#347BFF","pink":"#FF4BB8"}.items():
  (d/("icon_"+name+".xml")).write_text('<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item><shape android:shape="rectangle"><solid android:color="'+color+'"/><corners android:radius="24dp"/></shape></item><item android:left="6dp" android:top="6dp" android:right="6dp" android:bottom="6dp" android:drawable="@mipmap/ic_launcher"/></layer-list>')
def create_activity():
 p=ROOT/"android/app/src/main/kotlin/com/example/b_music02/MainActivity.kt";p.parent.mkdir(parents=True,exist_ok=True);p.write_text((ROOT/"tool/MainActivity.kt").read_text())
def main():
 manifest=ROOT/"android/app/src/main/AndroidManifest.xml";configure_manifest(manifest);create_activity();create_notification_icon();create_launcher_icons();patch_audio_query(ROOT/".dart_tool/package_config.json");verify_source_manifest(manifest);print("B_music02 Android yapılandırması tamamlandı.")
if __name__=="__main__":main()
