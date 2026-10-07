# Google Play hazırlığı

| | |
| --- | --- |
| Paket adı | `com.bmusic.app` (eski GitHub sürümleri: `com.example.b_music02`) |
| Telefondaki ad | **B Music** |
| Play'deki başlık (ileride) | **B Music: Müzik ve Video Oynatıcı** |
| Geliştirici hesabı | Kişisel |
| İletişim e-postası | bmusiciletisim@gmail.com |
| Gizlilik politikası | `docs/privacy.html` (GitHub Pages ya da başka bir herkese açık adreste yayımlanmalı) |
| Veri silme | `docs/delete-account.html` (hesap yok; Öneri Kutusu için e-posta) |
| İmza | Kalıcı yükleme anahtarı (GitHub secret `BMUSIC_KEYSTORE_*`), SHA-256 `0594c4bb…9428c0e`. Play App Signing'e geçerken bu anahtar "upload key" olarak kullanılabilir. |

## İzinler ve gerekçeleri

Yalnızca gerekenler var. Kaynağı `tool/configure_android.py` (`PERMISSIONS`); her
derlemede `tool/verify_apk_manifest.py` gereksiz izin (mikrofon, kamera, konum,
kişiler, `USE_EXACT_ALARM`, reklam kimliği) olmadığını denetler.

| İzin | Neden | Play notu |
| --- | --- | --- |
| `READ_MEDIA_AUDIO`, `READ_MEDIA_VIDEO` (Android 13+), `READ_EXTERNAL_STORAGE` (≤ Android 12), `WRITE_EXTERNAL_STORAGE` (≤ Android 9) | Telefondaki müzik ve videoları listelemek, kırpma/GIF/ses çıkarma çıktısını kaydetmek | Uygulamanın ana işlevi |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Ekran kapalıyken müzik, video sesi ve alarm sesi | Play Console → "Ön plan hizmeti izinleri": *Medya oynatma* seçilmeli, kısa video eklenmeli |
| `WAKE_LOCK` | Ekran kapalıyken oynatma ve alarm | — |
| `POST_NOTIFICATIONS` | Oynatıcı, duyuru ve alarm bildirimleri (Android 13+ bir kez sorulur) | — |
| `INTERNET` (ve Firebase'in eklediği `ACCESS_NETWORK_STATE`, `c2dm RECEIVE`) | Anlık bildirim (FCM), Analytics, Crashlytics, Öneri Kutusu, GitHub sürüm denetimi | Data safety formunda belirtilmeli (aşağıda) |
| `SCHEDULE_EXACT_ALARM` | Müzikli alarm tam zamanında çalsın. Android 14'te kullanıcı izni gerekir; uygulama Alarm ekranında "İzin ver" bandı gösterir, izin yoksa alarm yine (birkaç dakika gecikmeyle) çalar | `USE_EXACT_ALARM` bilinçli olarak kullanılmıyor (Play yalnızca saat/alarm uygulamalarına izin verir) |
| `USE_FULL_SCREEN_INTENT` | Çalan alarm kilit ekranının üstünde tam ekran açılsın | Android 14+: Play yalnızca alarm/arama uygulamalarına otomatik verir. Play Console'da "Tam ekran amaç" beyanında **Alarm** seçilmeli; verilmezse alarm normal bildirim olarak çalar |
| `RECEIVE_BOOT_COMPLETED` | Telefon yeniden başlayınca kurulu alarmlar yeniden kurulur | — |
| `VIBRATE` | Alarm titreşimi | — |
| `REQUEST_INSTALL_PACKAGES` | Yalnızca GitHub APK'sı için uygulama içi güncelleme ("Yeni sürüm var" → indir → kur) | **Play'e yüklemeden önce kaldırılmalı.** Play, kendini Play dışından güncelleyen uygulamalara izin vermez. Uygulama Play'den kurulduğunda güncelleyici zaten kapanır (yükleyici `com.android.vending`), ama izin manifestte kaldığı sürece beyan formu gerekir. Play derlemesi için `PERMISSIONS`'tan `REQUEST_INSTALL_PACKAGES` satırını ve `configure_updates` çağrısını çıkarmak yeterli. |

`com.google.android.gms.permission.AD_ID` manifestten çıkarılır
(`tools:node="remove"`) ve Analytics'in reklam kimliği toplaması kapalıdır.

## Data safety (Veri güvenliği) formu için

- **Toplanan veriler:**
  - Uygulama etkileşimleri ve teşhis verileri: Firebase Analytics (ekran/oturum sayıları,
    `notification_open` olayı) ve Crashlytics (çökme günlükleri, cihaz modeli, Android sürümü).
    Amaç: analiz, uygulama işlevselliği. Kullanıcı Ayarlar → Gizlilik → "Kullanım ve hata raporları" ile kapatabilir.
  - Cihaz kimliği: FCM kayıt jetonu ve Firebase kurulum kimliği (bildirim için).
  - Kullanıcının yazdığı metin: Öneri Kutusu (isteğe bağlı iletişim bilgisi, sürüm, cihaz modeli) — Firestore.
- **Paylaşılan veri:** yok (Google, hizmet sağlayıcı olarak işler).
- **Aktarım şifreli:** evet (HTTPS).
- **Silme talebi:** bmusiciletisim@gmail.com.
- Hesap yok, konum yok, reklam yok, satın alma yok.

## Mağaza metni önerisi

**Kısa açıklama (80 karakter):** Telefonundaki müzik ve videoları reklamsız, hızlı ve şık bir oynatıcıda aç.

**Uzun açıklama:** B Music; telefonundaki şarkıları ve videoları tek bir yerde toplar.
Albüm, sanatçı ve klasöre göre müzik, ekolayzer, uyku zamanlayıcısı, sevdiğin şarkıyla
alarm, kaldığın yerden devam eden videolar, yukarı kaydırarak sonraki videoya geçiş,
çift dokunarak favorilere ekleme, kırpma, GIF ve ekran görüntüsü, yüzen video ve ekran
kapalıyken dinleme. Hesap gerekmez; dosyaların telefonundan çıkmaz.

## Play'e geçmeden önce yapılacaklar

1. `REQUEST_INSTALL_PACKAGES` ve güncelleyiciyi Play derlemesinden çıkar (yukarıda).
2. Android App Bundle üret: `flutter build appbundle --release`.
3. Firebase'de Google Analytics bağlantısını aç (Proje ayarları → Entegrasyonlar → Google Analytics).
4. Play Console'da Data safety, Ön plan hizmeti (medya oynatma) ve Tam ekran amaç (Alarm) beyanlarını doldur.
5. Gizlilik politikasını herkese açık bir adreste yayımla ve Play Console'a ekle.
