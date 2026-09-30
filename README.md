# B_music02

Türkçe, Android için cihazdaki müzikleri ve videoları oynatan Flutter uygulaması.

## Uygulama

Ana Sayfa, Müzik, Video, Listeler ve Ayarlar bölümleri. Gerçek cihaz müzikleriyle çalışan arama, sanatçı/albüm/klasör grupları, favoriler, oynatma sırası, kalıcı listeler, kaldığı yeri hatırlama, uyku zamanlayıcısı ve sistem medya kontrolleri. Çevrimiçi Keşfet ve açık lisanslı müzik indirme mevcut servisleri kullanır. YouTube API anahtarı `YOUTUBE_API_KEY` GitHub Actions secret alanından derlemeye aktarılır.

## Geliştirme

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
flutter create --platforms=android --org com.example --project-name b_music02 --no-pub .
cp /tmp/b_music02-pubspec.lock pubspec.lock
rm -f test/widget_test.dart
flutter pub get --enforce-lockfile
python3 tool/configure_android.py
dart run flutter_launcher_icons
flutter build apk --release
```

Yerel derlemelerde YouTube API anahtarı ayrıca `--dart-define=YOUTUBE_API_KEY=...` ile aktarılmalıdır. Anahtar yoksa veya çevrimiçi sonuçlara ulaşılamazsa YouTube’da aramaya devam etme ve Wikimedia üzerinde izinli müzik bulma seçenekleri kullanılabilir.

Başarılı `main` derlemeleri APK ve SHA-256 dosyasını GitHub Releases'a yayınlar. Testler cihaz erişimini, fiziksel telefonun üreticiye özel pil/bildirim davranışını veya canlı çevrimiçi servisleri taklit ederek onaylamaz; gerçek cihaz testi ayrıca gereklidir.

## Veri uyumluluğu

Eski favori, liste, tema ve ses ayarlarının anahtarları korunur. Liste veya sıra silmek telefondaki müzik dosyalarını silmez. Açılışta kayıtlı sıra duraklatılmış olarak yüklenir. Gelişmiş Ayarlar bölümünden bu davranış kapatılabilir.
