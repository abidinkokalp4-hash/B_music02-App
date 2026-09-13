import sys
import xml.etree.ElementTree as ET

A = '{http://schemas.android.com/apk/res/android}'
root = ET.parse(sys.argv[1]).getroot()
app = root.find('application')
assert app is not None
assert any(e.get(A + 'name') == 'com.ryanheise.audioservice.AudioService' and
           e.get(A + 'foregroundServiceType') == 'mediaPlayback' for e in app.findall('service'))
assert any(e.get(A + 'name') == 'com.ryanheise.audioservice.MediaButtonReceiver' for e in app.findall('receiver'))
permissions = {e.get(A + 'name'): e for e in root.findall('uses-permission')}
for name in ('INTERNET', 'WAKE_LOCK', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'READ_MEDIA_AUDIO'):
    assert 'android.permission.' + name in permissions, name
assert permissions['android.permission.READ_EXTERNAL_STORAGE'].get(A + 'maxSdkVersion') == '32'
print('Built APK contains the media service, receiver and required permissions.')
