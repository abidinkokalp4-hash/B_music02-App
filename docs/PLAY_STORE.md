# Google Play hazırlığı — B Music

| | |
| --- | --- |
| Paket adı (applicationId) | `com.bmusic.app` (eski GitHub sürümleri: `com.example.b_music02`) |
| Telefondaki ad | **B Music** |
| Play başlığı | **B Music: Müzik ve Video Çalar** (29 karakter). İstenen "B Music: Müzik ve Video Oynatıcı" 32 karakter; Play sınırı 30 olduğu için sığmıyor. |
| Geliştirici hesabı | Kişisel |
| İletişim e-postası | bmusiciletisim@gmail.com |
| Gizlilik politikası | https://abidinkokalp4-hash.github.io/B_music02-App/privacy.html |
| Veri silme | https://abidinkokalp4-hash.github.io/B_music02-App/delete-account.html (hesap yok; Öneri Kutusu ve diğer veriler için e-posta) |
| Mağaza metinleri ve görseller | `store/` (`store/listing-tr.md`, `icon-512.png`, `feature-graphic.png`, `screenshots/`) |
| Play derlemesi | Her `main` derlemesinde GitHub sürümüne eklenen **`B_Music_play.aab`** |
| Hedef API | `targetSdk 36` (Play: 31 Ağustos 2026'dan beri yeni uygulama ve güncellemeler için API 36 zorunlu); CI her paket için denetler |

## İki derleme, tek kaynak

| | GitHub APK (`B_music02.apk`) | Google Play (`B_Music_play.aab`) |
| --- | --- | --- |
| Komut | `flutter build apk` | `BMUSIC_STORE=play python3 tool/configure_android.py` + `flutter build appbundle --dart-define=BMUSIC_STORE=play` |
| Uygulama içi güncelleyici | Açık ("Yeni sürüm var" → indir → kur) | **Yok** (Dart'ta `kPlayBuild`, Kotlin'de `com.bmusic.app.STORE=play`) |
| `REQUEST_INSTALL_PACKAGES` | Var | **Yok** (`tools:node="remove"`; CI `bundletool dump manifest` ile denetler) |
| Güncelleme FileProvider'ı | Var | Yok |
| "Uygulamayı paylaş" bağlantısı | GitHub APK bağlantısı | `https://play.google.com/store/apps/details?id=com.bmusic.app` |
| versionCode | CI çalıştırma numarası | Aynı numara (her sürümde artar) |
| İmza | Kalıcı B Music anahtarı | Aynı anahtar = **Play yükleme anahtarı (upload key)** |

CI denetimleri (`.github/workflows/build-apk.yml`, `tool/verify_play_bundle.py`):
paket `com.bmusic.app`, versionCode = çalıştırma numarası, `targetSdk ≥ 36`,
`REQUEST_INSTALL_PACKAGES`/`USE_EXACT_ALARM`/reklam kimliği yok, güncelleme provider'ı yok,
`bundletool validate`, imza sertifikası SHA-256 = `tool/release_signing_cert.sha256`
(`0594c4bb718b3886c05969848dfbcb82ec9a5490c16d7d3e4426a13ba9428c0e`).

### İmza: Play App Signing + yükleme anahtarı

- Play Console'da uygulamayı oluştururken **Play App Signing** açık kalsın (varsayılan:
  "Google tarafından oluşturulan uygulama imzalama anahtarı").
- Yüklediğimiz `B_Music_play.aab`, GitHub secret'larındaki B Music anahtarıyla imzalı; Play
  bu anahtarı ilk yüklemede **upload key** olarak kaydeder. Sonraki her AAB aynı anahtarla
  imzalanmalı (CI bunu zaten yapar ve denetler).
- Sonuç: Play'den kurulan uygulamayı Google'ın anahtarı imzalar. **GitHub APK'sı ile Play
  sürümü birbirinin üzerine kurulamaz** (imzalar farklı). GitHub'dan kurmuş biri Play'e geçmek
  isterse: Ayarlar → İçe / Dışa aktar → "Yedeği dışa aktar", GitHub sürümünü kaldır,
  Play'den kur, yedeği içe aktar.
- İsteğe bağlı alternatif (yalnızca ilk yüklemeden önce seçilebilir): "Mevcut uygulama imzalama
  anahtarını kullan" + Google'ın PEPK aracıyla B Music anahtarını yüklemek. O zaman Play ve
  GitHub sürümleri aynı imzayı taşır ve birbirinin üzerine güncellenir. Anahtar dosyası yalnızca
  sahibinde olduğu için bu adımı sahibi yapmalı; yapılmazsa yukarıdaki varsayılan geçerlidir.
- Yükleme anahtarı kaybolursa Play Console → Uygulama bütünlüğü → "Yükleme anahtarını sıfırla"
  ile yenisi istenebilir (uygulama imzalama anahtarı Google'da kalır).

## İzinler ve Play Console beyanları

Kaynak: `tool/configure_android.py` (`PERMISSIONS`). Mikrofon, kamera, konum, kişiler,
`USE_EXACT_ALARM`, `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE` ve reklam kimliği yok;
CI bunu hem APK hem AAB için denetler.

| İzin | Neden | Play Console'da |
| --- | --- | --- |
| `READ_MEDIA_AUDIO`, `READ_MEDIA_VIDEO` (Android 13+), `READ_EXTERNAL_STORAGE` (≤ 12), `WRITE_EXTERNAL_STORAGE` (≤ 9) | Telefondaki müzik ve videoları listelemek/oynatmak; kırpma, GIF, ses çıkarma çıktısını kaydetmek | Uygulamanın ana işlevi. ("Fotoğraf ve video izinleri" beyanı sorulursa aşağıdaki metin) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK` | Ekran kapalıyken / arka planda müzik, video sesi ve alarm sesi | **Ön plan hizmeti beyanı: "Medya oynatma"** + kısa video bağlantısı |
| `POST_NOTIFICATIONS` | Oynatıcı kontrolleri, duyurular, alarm bildirimi | Beyan gerekmez |
| `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` | Müzikli alarm tam saatinde çalsın, yeniden başlatmadan sonra kurulu kalsın | Beyan gerekmez. `USE_EXACT_ALARM` **bilerek kullanılmıyor**: Play onu yalnızca ana işlevi saat/alarm/takvim olan uygulamalara verir; B Music'in ana işlevi medya oynatma, alarm ek özellik. Android 14+'da kullanıcı "Alarmlar ve anımsatıcılar" iznini verir (uygulama Alarm ekranında bant gösterir) |
| `USE_FULL_SCREEN_INTENT` | Çalan alarm kilit ekranının üstünde tam ekran açılsın | **Tam ekran amaç beyanı: "Alarm"**. Play reddederse izin varsayılan kapalı kalır ve alarm yüksek öncelikli bildirim olarak çalar (uygulama bunu destekler); gerekirse Play derlemesinden çıkarılabilir |
| `INTERNET`, `ACCESS_NETWORK_STATE` (Firebase) | Anlık bildirim (FCM), Analytics, Crashlytics, Öneri Kutusu | Data safety formunda |

### Yapıştırılacak gerekçe metinleri

**Ön plan hizmeti — Medya oynatma (FOREGROUND_SERVICE_MEDIA_PLAYBACK)**

> TR: B Music bir müzik ve video oynatıcıdır. Kullanıcı bir şarkı ya da videonun sesini başlattığında, uygulama arka plandayken veya ekran kapalıyken çalmaya devam etmek için medya oynatma türünde ön plan hizmeti kullanır. Bildirimde oynat/duraklat, sonraki/önceki kontrolleri görünür; kullanıcı duraklattığında veya kapattığında hizmet durur. Müzikli alarm çaldığında seçilen şarkı da aynı hizmetle çalınır ve kullanıcı "Durdur"a bastığında hizmet sona erer.
>
> EN: B Music is a music and video player. When the user starts a song or a video's audio, the app uses a media-playback foreground service so playback continues while the app is in the background or the screen is off. The notification shows play/pause and next/previous controls; the service stops when the user pauses or dismisses playback. When a music alarm rings, the chosen song is played by the same service and it ends when the user taps "Stop".

Video için: telefonda şarkı başlat → ana ekrana dön → bildirimdeki kontroller → ekranı kapat, müzik
sürsün (30 sn yeterli; YouTube'a "liste dışı" yüklenip bağlantısı verilir).

**Tam ekran amaç — Alarm (USE_FULL_SCREEN_INTENT)**

> TR: B Music'te kullanıcının kurduğu müzikli alarm vardır (Daha Fazla → Alarm). Alarm saati geldiğinde, telefon kilitliyken bile alarmı fark edip "Ertele" veya "Durdur" diyebilmesi için tam ekran alarm ekranı açılır. İzin yalnızca kullanıcının kendi kurduğu alarm çaldığında kullanılır; başka hiçbir bildirim tam ekran gösterilmez.
>
> EN: B Music includes a user-configured music alarm (More → Alarm). When the alarm time arrives, a full-screen alarm screen is shown, even on the lock screen, so the user can notice it and tap "Snooze" or "Stop". The permission is used only when an alarm set by the user rings; no other notification is shown full screen.

**Tam zamanlı alarm (SCHEDULE_EXACT_ALARM)** — beyan formu yok; sorulursa:

> TR: Kullanıcının kurduğu müzikli alarmın tam seçilen saatte çalması için AlarmManager ile tam zamanlı alarm kurulur. İzin yalnızca kullanıcı bir alarm kaydettiğinde kullanılır; kullanıcı izni sistem ayarlarından kapatabilir, bu durumda alarm birkaç dakika gecikmeyle çalar.
>
> EN: An exact AlarmManager alarm is scheduled so the user's music alarm rings at the exact time they chose. It is used only when the user saves an alarm; the user can revoke the permission in system settings, in which case the alarm may ring a few minutes late.

**Medya erişimi (READ_MEDIA_AUDIO / READ_MEDIA_VIDEO)** — sorulursa:

> TR: B Music, telefondaki şarkıları ve videoları listeleyip oynatan yerel bir medya oynatıcıdır; bu, uygulamanın ana işlevidir. Dosyalar yalnızca cihazda okunur, hiçbir sunucuya yüklenmez.
>
> EN: B Music is a local media player that lists and plays the songs and videos stored on the phone; this is the app's core functionality. Files are only read on the device and are never uploaded to any server.

**Bildirimler (POST_NOTIFICATIONS)** — sorulursa:

> TR: Oynatma kontrolleri (oynat/duraklat, sonraki), çalan alarm ve isteğe bağlı B Music duyuruları için bildirim gösterilir. Duyurular Ayarlar → Bildirimler'den kapatılabilir.
>
> EN: Notifications are used for playback controls (play/pause, next), a ringing alarm and optional B Music announcements. Announcements can be turned off in Settings → Notifications.

## Data safety (Veri güvenliği) formu

| Soru | Cevap |
| --- | --- |
| Uygulama kullanıcı verisi topluyor veya paylaşıyor mu? | **Evet, topluyor** |
| Toplanan tüm veriler aktarım sırasında şifreleniyor mu? | **Evet** (HTTPS / TLS) |
| Kullanıcılar verilerinin silinmesini isteyebilir mi? | **Evet** — e-posta: bmusiciletisim@gmail.com (bağlantı: delete-account.html) |
| Hesap oluşturma | **Yok** (giriş yok) |
| Veri paylaşımı (üçüncü taraf) | **Yok.** Google/Firebase "hizmet sağlayıcı" olarak işler; Play'e göre bu paylaşım sayılmaz |

Toplanan veri türleri:

| Play kategorisi → türü | Kaynak | Zorunlu mu? | Amaç |
| --- | --- | --- | --- |
| Uygulama etkinliği → **Uygulama etkileşimleri** | Firebase Analytics (açılan ekranlar, oturumlar, `notification_open`) | İsteğe bağlı (Ayarlar → Gizlilik → "Kullanım ve hata raporları") | Analiz |
| Uygulama bilgileri ve performans → **Kilitlenme günlükleri**, **Teşhis** | Firebase Crashlytics (çökme yığını, cihaz modeli, Android sürümü, uygulama sürümü) | İsteğe bağlı (aynı anahtar) | Uygulama işlevselliği, analiz |
| Cihaz veya diğer kimlikler → **Cihaz veya diğer kimlikler** | Firebase kurulum kimliği, FCM kayıt jetonu | Zorunlu (bildirimler için) | Uygulama işlevselliği (anlık bildirim), analiz |
| Uygulama etkinliği → **Kullanıcının oluşturduğu diğer içerikler** | Öneri Kutusu mesajı (+ uygulama sürümü, Android sürümü, cihaz modeli) — Firestore | İsteğe bağlı (yalnızca kullanıcı gönderirse) | Geliştirici iletişimi |
| Kişisel bilgiler → **E-posta adresi** (veya diğer iletişim bilgisi) | Öneri Kutusu'ndaki isteğe bağlı "iletişim" alanı | İsteğe bağlı | Geliştirici iletişimi |

Toplanmayanlar: konum, kişiler, fotoğraf/video/ses dosyaları (yalnızca cihazda okunur), mesajlar,
takvim, finans, sağlık, tarama geçmişi, reklam kimliği (AD_ID manifestten çıkarıldı). Veriler
"geçici olarak işlenir" değil, Firebase'de saklanır (Analytics/Crashlytics varsayılan saklama süreleri).

## İçerik derecelendirmesi (IARC anketi)

- Kategori: **"Diğer tüm uygulama türleri"** (oyun değil; sosyal/iletişim değil).
- Şiddet, cinsellik, küfür, uyuşturucu, kumar: **Hayır**.
- Kullanıcılar birbiriyle etkileşebilir / içerik paylaşabilir mi? **Hayır** (Öneri Kutusu yalnızca geliştiriciye gider, kimse göremez).
- Konum paylaşımı: **Hayır**. Dijital satın alma: **Hayır**. Sınırsız internet erişimi (tarayıcı): **Hayır**.
- Uygulama yalnızca kullanıcının kendi cihazındaki dosyaları oynatır.
- Beklenen sonuç: **3+ / PEGI 3 / Genel izleyici**.

## Hedef kitle ve içerik

- Hedef yaş grupları: **13–15, 16–17, 18 ve üzeri** (13 yaş altı seçilmez → Aileler politikası
  kapsamına girmez). En basit inceleme için yalnızca "18 ve üzeri" de seçilebilir.
- "Uygulama çocuklara hitap ediyor mu?" sorulursa: **Hayır**.
- Reklam içeriyor mu? **Hayır**. Uygulama içi satın alma: **Yok**.
- Haber uygulaması: Hayır. Sağlık/finans/devlet: Hayır. COVID: Hayır.
- Uygulama erişimi: **Tüm işlevler özel erişim olmadan kullanılabilir** (giriş yok).
- Kategori: **Müzik ve Ses** (alternatif: Video Oynatıcılar ve Düzenleyiciler). Etiketler: müzik çalar, video oynatıcı.

## Play Console adımları (sahibi yapar)

1. Kimlik doğrulaması onaylanınca: **Uygulama oluştur** → ad "B Music: Müzik ve Video Çalar",
   varsayılan dil Türkçe, Uygulama, Ücretsiz; beyanları onayla.
2. **Uygulama içeriği**: Gizlilik politikası URL'si, Uygulama erişimi (tümü serbest), Reklamlar (yok),
   İçerik derecelendirmesi (yukarıda), Hedef kitle (yukarıda), Data safety (yukarıda),
   Ön plan hizmeti (Medya oynatma + video), Tam ekran amaç (Alarm), Haber/Devlet/Sağlık: hayır.
3. **Ana mağaza girişi**: `store/listing-tr.md` metinleri, `store/icon-512.png`,
   `store/feature-graphic.png`, `store/screenshots/` (4–8 adet; çerçeveli ya da ham).
4. **Test → Kapalı test**: yeni kanal oluştur, test kullanıcıları için e-posta listesi (Google Grubu
   veya liste) ekle, **en son GitHub sürümündeki `B_Music_play.aab`'ı yükle**, sürüm notu yaz,
   incelemeye gönder. Play App Signing'i ilk yüklemede onayla (yukarıdaki imza bölümü).
5. 2023 sonrası açılan **kişisel hesaplarda** üretime çıkmak için: kapalı testte **en az 12 test kullanıcısı
   14 gün boyunca kesintisiz** katılmış olmalı. Test kullanıcıları katılım bağlantısından katılıp
   uygulamayı Play'den kurmalı ve ara ara kullanmalı.
6. 14 gün dolunca Kontrol paneli → **Üretime erişim başvurusu** (test hakkında birkaç soru).
   Onaylanınca **Üretim** kanalına aynı/yeni AAB ile sürüm oluştur, ülkeler: Türkiye (+ istenirse diğerleri).
7. Sonraki sürümler: `main`'e her birleştirmede yeni `B_Music_play.aab` (artan versionCode) çıkar;
   Play Console'da ilgili kanala yükle.

İsteğe bağlı: Play Console uyarı verirse R8 eşleme dosyası (deobfuscation) ve yerel hata ayıklama
sembolleri yüklenebilir; zorunlu değil.
