import sys
import xml.etree.ElementTree as ET

A = '{http://schemas.android.com/apk/res/android}'

root = ET.parse(sys.argv[1]).getroot()

app = root.find('application')
assert app is not None, 'application elementi bulunamadi'
assert any(
    e.get(A + 'name') == 'io.flutter.embedding.android.EnableImpeller'
    and e.get(A + 'value') == 'false'
    for e in app.findall('meta-data')
), 'Flutter 3.47.4 renderer uyumluluk ayari eksik'

services = {
    e.get(A + 'name'): e
    for e in app.findall('service')
}

service_name = 'com.ryanheise.audioservice.AudioService'

assert service_name in services, (
    'AudioService APK manifestinde bulunamadi. '
    f'Bulunan servisler: {list(services.keys())}'
)

service = services[service_name]

fg_type = service.get(A + 'foregroundServiceType')

assert fg_type in ('mediaPlayback', '2', '0x2', '0x00000002'), (
    'AudioService foregroundServiceType beklenmeyen deger: '
    f'{fg_type!r}'
)

assert service.get(A + 'exported') == 'true', 'AudioService exported olmali'
assert service.get(A + 'enabled', 'true') == 'true', 'AudioService kapali'
assert any(
    action.get(A + 'name') == 'android.media.browse.MediaBrowserService'
    for action in service.findall('intent-filter/action')
), 'MediaBrowserService intent-filter eksik'
assert any(
    activity.get(A + 'name') == 'com.example.b_music02.MainActivity'
    and activity.get(A + 'exported') == 'true'
    for activity in app.findall('activity')
), 'AudioServiceActivity eksik'

# Announcement checks run through WorkManager's JobScheduler service.
assert 'androidx.work.impl.background.systemjob.SystemJobService' in services, 'WorkManager servisi eksik'

# Instant announcements: FCM's MESSAGING_EVENT must resolve to our service.
# The SDK's own base service stays as the priority -500 fallback.
push = services.get('com.example.b_music02.PushMessagingService')
assert push is not None, 'PushMessagingService (FCM) eksik'
assert push.get(A + 'exported') == 'false', 'PushMessagingService exported olmamali'
def _priority(e):
    f = next((f for f in e.findall('intent-filter')
              if any(a.get(A + 'name') == 'com.google.firebase.MESSAGING_EVENT' for a in f.findall('action'))), None)
    return None if f is None else int(f.get(A + 'priority', '0'))
messaging = {n: _priority(e) for n, e in services.items() if _priority(e) is not None}
top = max(messaging.values())
assert [n for n, p in messaging.items() if p == top] == ['com.example.b_music02.PushMessagingService'], (
    f'FCM mesajlari baska servise gidebilir: {messaging}')
assert 'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService' not in services, (
    'firebase_messaging eklentisinin servisi kaldirilmamis')
assert any(e.get(A + 'name') == 'com.google.firebase.messaging.default_notification_channel_id'
           and e.get(A + 'value') == 'announcements' for e in app.findall('meta-data')), 'FCM varsayilan kanal ayari eksik'

receivers = {
    e.get(A + 'name')
    for e in app.findall('receiver')
}

assert 'com.ryanheise.audioservice.MediaButtonReceiver' in receivers, (
    'MediaButtonReceiver APK manifestinde bulunamadi. '
    f'Bulunan receiverlar: {sorted(x for x in receivers if x)}'
)
assert 'com.example.b_music02.MusicWidgetProvider' in receivers, 'Ana ekran widgeti eksik'

permissions = {
    e.get(A + 'name'): e
    for e in root.findall('uses-permission')
}

for name in (
    'WAKE_LOCK',
    'FOREGROUND_SERVICE',
    'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'READ_MEDIA_AUDIO',
    'POST_NOTIFICATIONS',
):
    full_name = 'android.permission.' + name
    assert full_name in permissions, (
        f'Eksik Android izni: {full_name}'
    )

storage = permissions.get(
    'android.permission.READ_EXTERNAL_STORAGE'
)

assert storage is not None, (
    'READ_EXTERNAL_STORAGE izni bulunamadi'
)

assert storage.get(A + 'maxSdkVersion') == '32', (
    'READ_EXTERNAL_STORAGE maxSdkVersion 32 degil: '
    f'{storage.get(A + "maxSdkVersion")!r}'
)

print('APK manifest dogrulamasi basarili.')
print('AudioService:', service_name)
print('foregroundServiceType:', fg_type)
print('MediaButtonReceiver: OK')
print('Gerekli izinler: OK')

assert 'android.permission.INTERNET' in permissions, 'YouTube oynatıcı internet izni gerektirir'

activity = next(a for a in app.findall('activity') if a.get(A + 'name') == 'com.example.b_music02.MainActivity')
assert any(e.get(A + 'name') == 'flutter_deeplinking_enabled' and e.get(A + 'value') == 'false'
           for e in activity.findall('meta-data')), 'Harici medya Flutter rotasi olarak acilmamali'
