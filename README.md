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


## Yerel müzik ve güncel Android derlemesi

**Müzikler** sekmesinde erişim düğmesine dokunun. Android müzik/ses iznini
verdiğinizde MediaStore içindeki ses dosyaları otomatik listelenir. İzin daha önce
verilmişse açılışta ve uygulamaya geri dönüşte arşiv yenilenir. Kalıcı ret durumunda
**Uygulama ayarlarını aç** düğmesiyle müzik erişimini etkinleştirin. Yenile düğmesi
yeni dosyaları tarar; çalan müziğin sırasını değiştirmez.

- Favoriler, çalma listeleri ve karışık/tekrar tercihleri cihazda saklanır.
- **Yeni liste** ile liste oluşturun. Müziğe basılı tutarak listeye ekleyin/çıkarın.
- Liste seçildiğinde üç nokta menüsünden adı değiştirilebilir veya liste silinebilir;
  liste silmek telefondaki dosyaları silmez.
- Favoriler, arama sonucu veya listeden başlatılan oynatma o seçimle sınırlıdır.
- Mini oynatıcıya dokununca kapak, ilerleme çubuğu, önceki/sonraki,
  favori, karışık ve kapalı/tümü/tek tekrar kontrolleri açılır.
- Yerel müzik için `audio_service` bildirim, kulaklık düğmeleri ve kilit ekranını
  yönetir. YouTube arama servisi ve mevcut WebView oynatımı korunur.
- Kapağı bulunmayan dosyalarda varsayılan müzik görseli gösterilir.

Yerel Android hazırlığı: `python3 tool/prepare_platforms.py`. Ardından
`dart run flutter_launcher_icons` ve `flutter run` çalıştırılabilir.
`flutter pub get` sonrasında `python3 tool/configure_android.py` komutu eski
`on_audio_query_android` paketinin AGP namespace uyumluluğunu tekrar uygular.

Güncel Actions adı **B_music02 APK Build**, çıktı adı **B_music02-APK**.
İş akışı Python yapılandırma testlerini ve Dart analizini çalıştırır; release APK
üretir ve APK'nın içindeki izin/servis kayıtlarını denetler. `YOUTUBE_API_KEY`
mevcut GitHub secret üzerinden aktarılmaya devam eder. Önceki derlemedeki
`com.example.b_music02` uygulama kimliği korunur. Bu iş akışı AAB üretmez ve Play
Store için kalıcı imzalama yapılandırmaz; Flutter'ın varsayılan release/debug
imzasını kullanır. Önceki APK farklı anahtarla imzalanmışsa yerinde güncellenemez.

Cihaz kabul kontrolü: izin verme/ret/ayarlardan geri dönüş; ekran kilitliyken
çalma ve bildirimden duraklat/önceki/sonraki; kulaklık çıkarma ve telefon çağrısı;
kapaklı/kapaksız dosya; favori/listenin yeniden açılışta korunması; karışık ve üç
tekrar modu; çalan sırada arşivi yenileme; YouTube araması ve video açma.
Fiziksel cihaz sonuçları ayrıca doğrulanmalıdır.
