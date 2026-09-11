# B_music02

B_music02, TikTok müzik sayfasını bağımsız bir mobil topluluk deneyimine dönüştüren Flutter uygulamasıdır.

## İlk milestone'da çalışan özellikler

- Animasyonlu splash ekranı ve marka karşılama metni
- Giriş / üye ol akışı (yerel demo oturumu)
- Premium koyu tema, bordo ve altın vurgu renkleri
- Video kartları, arama ve kategori filtreleri
- Video kartına dokununca TikTok uygulamasını açma; TikTok açılamazsa harici tarayıcıya geçiş
- Müzik talebi oluşturma ve oy verme demo akışı
- Reklam başvuru formu
- Genel sohbet demo akışı
- Galeriden profil fotoğrafı seçme
- Android APK ve AAB üreten GitHub Actions iş akışı
- Android/iOS platform temelini otomatik üretme (`com.bmusic02.app`)

## Önemli: TikTok videoları

Bu sürüm TikTok profil linkiyle çalışan demo kartları içerir. Gerçek tekil videoların uygulamada listelenmesi için her videonun TikTok URL'si `DemoRepository` içindeki kayıtlarla değiştirilmelidir veya sonraki milestone'da resmi TikTok API / yönetim paneli bağlanmalıdır. Uygulama videoyu kendi içinde oynatmaz; dışarıdaki TikTok uygulamasına yönlendirir.

## Logo / uygulama simgesi

`assets/images/b_music02_logo.png` şu an geçici B_music02 simgesidir. TikTok profil fotoğrafınızı aynı dosya adıyla değiştirip `dart run flutter_launcher_icons` çalıştırdığınızda Android ve iOS uygulama simgeleri profil resminizden üretilir.

## Bilgisayarda çalıştırma

Flutter SDK kurulu bir bilgisayarda:

```bash
python3 tool/prepare_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Telefona APK indirme

1. GitHub deposunda **Actions** sekmesine girin.
2. **Build Android APK** iş akışını açın.
3. Son başarılı çalıştırmayı seçin.
4. Sayfanın altındaki **Artifacts** bölümünden `B_music02-APK` dosyasını indirin.
5. ZIP içindeki `app-release.apk` dosyasını Android telefona kurun.

Google Play için aynı çalıştırmada `B_music02-AAB` çıktısı da oluşturulur.

## Sonraki milestone

- Firebase Authentication
- Firestore gerçek zamanlı sohbet
- Firebase Storage profil fotoğrafları
- Firestore talep ve reklam başvuruları
- Admin paneli
- Bildirimler
- TikTok video senkronizasyonu
- Şikâyet / engelleme / moderasyon sistemi
- Play Store release signing ve mağaza hazırlığı
