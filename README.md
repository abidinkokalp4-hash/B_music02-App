# B Music

Türkçe, Android için cihazdaki müzikleri ve videoları oynatan Flutter uygulaması.
Paket adı `com.bmusic.app`; Google Play başlığı **B Music: Müzik ve Video Çalar** (30 karakter sınırı). Her sürümde GitHub APK'sı (`B_music02.apk`, kendini günceller) ve Google Play App Bundle'ı (`B_Music_play.aab`, güncelleyicisiz) çıkar. Play hazırlığı, beyanlar ve Data safety: [docs/PLAY_STORE.md](docs/PLAY_STORE.md); mağaza metinleri ve görseller: [store/](store/); gizlilik politikası: https://abidinkokalp4-hash.github.io/B_music02-App/privacy.html
İletişim: bmusiciletisim@gmail.com

## Uygulama

Ana Sayfa, Müzik, Video, Listeler ve Ayarlar bölümleri. Gerçek cihaz müzikleriyle çalışan arama, sanatçı/albüm/klasör grupları, favoriler, oynatma sırası, kalıcı listeler, kaldığı yeri hatırlama, uyku zamanlayıcısı ve sistem medya kontrolleri. Tamamen yerel müzik/video arşivi: video favorileri, son izlenenler, kalıcı video devam noktası, liste/kart görünümü. Müzikli alarm (Daha Fazla → Alarm), uygulama içi güncelleme (yalnızca GitHub APK'sı), Öneri Kutusu, anlık bildirimler ve zamanlanmış selamlar (bkz. [docs/DUYURU.md](docs/DUYURU.md)). İndirme, çevrimiçi keşif veya hesap bağlantısı yoktur.

İnternet yalnızca Firebase (bildirim, Analytics, Crashlytics, Öneri Kutusu) ve GitHub sürüm denetimi için kullanılır; hepsi ücretsiz Spark planındadır.

- **Öneri Kutusu'nu okumak:** `python3 tool/read_feedback.py` (Firebase CLI girişiyle) ya da Firebase konsolu → Firestore Database → `feedback`.
- **Kullanıcı sayısı ve bildirim açılmaları:** Firebase konsolu → Analytics → Dashboard / Realtime; olaylar → `notification_open` (`source`: `github`, `fcm` ya da `fcm_system`). Önce Proje ayarları → Entegrasyonlar → Google Analytics bağlanmalıdır.

## Geliştirme

Listeler bölümünde bir listenin menüsünden **Ana sayfaya sabitle** seçildiğinde
özel kapağıyla bir kısayol oluşturulur. Sabitlenen listeler ilk sırada görünür;
ad değişiklikleri ve yedekleme işlemleri sabitlemeleri korur. İndirilen bir
müzik silindiğinde çalma sırasındaki bütün kopyaları da kaldırılır.

Flutter 3.47.4 ve Java 17 kullanılır. Bağımlılıklar `pubspec.lock` ile sabitlenmiştir.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
python3 -m unittest discover -s test -p 'test_*.py' -v
```

Android klasörü kaynak depoda yoksa Actions tarafından hazırlanır:

```sh
cp pubspec.lock /tmp/b_music02-pubspec.lock
flutter create --platforms=android --org com.example --project-name b_music02 --no-pub .   # configure_android.py paketi com.bmusic.app yapar
cp /tmp/b_music02-pubspec.lock pubspec.lock
rm -f test/widget_test.dart
flutter pub get --enforce-lockfile
python3 tool/configure_android.py
dart run flutter_launcher_icons
flutter build apk --release
```



Başarılı `main` derlemeleri APK ve SHA-256 dosyasını GitHub Releases'a yayınlar. Testler cihaz erişimini, fiziksel telefonun üreticiye özel pil/bildirim davranışını veya canlı çevrimiçi servisleri taklit ederek onaylamaz; gerçek cihaz testi ayrıca gereklidir.

## Veri uyumluluğu

Eski favori, liste, tema ve ses ayarlarının anahtarları korunur. Liste veya sıra silmek telefondaki müzik dosyalarını silmez. Açılışta kayıtlı sıra duraklatılmış olarak yüklenir. Gelişmiş Ayarlar bölümünden bu davranış kapatılabilir.
