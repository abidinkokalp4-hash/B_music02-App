import sys
import xml.etree.ElementTree as ET

A = '{http://schemas.android.com/apk/res/android}'

root = ET.parse(sys.argv[1]).getroot()

app = root.find('application')
assert app is not None, 'application elementi bulunamadi'

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

receivers = {
    e.get(A + 'name')
    for e in app.findall('receiver')
}

assert 'com.ryanheise.audioservice.MediaButtonReceiver' in receivers, (
    'MediaButtonReceiver APK manifestinde bulunamadi. '
    f'Bulunan receiverlar: {sorted(x for x in receivers if x)}'
)

permissions = {
    e.get(A + 'name'): e
    for e in root.findall('uses-permission')
}

for name in (
    'INTERNET',
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
