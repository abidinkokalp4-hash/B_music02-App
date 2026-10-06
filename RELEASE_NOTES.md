B Music — anlık bildirimler

- Yeni: B Music duyuruları artık anında gelir (Firebase Cloud Messaging, ücretsiz).
  Uygulama açıkken, arka plandayken ve kapatılmışken de bildirim gösterilir.
- Aynı duyuru hem anlık bildirimle hem düzenli kontrolle (announcements.json) gelse
  bile yalnızca bir kez bildirilir; anlık gelen duyurular da Ayarlar → Bildirimler →
  Duyurular listesinde görünür.
- Bildirime dokununca Duyurular açılır; duyuruda bağlantı varsa tarayıcıda da açılır.
- Ayarlar → Bildirimler → "Duyuru bildirimleri" kapatılınca anlık bildirimler de durur.
- Android 13 ve üzerinde bildirim izni (verilmemişse) bir kez sorulur.
- Google Play hizmetleri olmayan telefonlarda uygulama normal çalışır; duyurular
  yaklaşık 4 saatte bir yapılan kontrolle gelmeye devam eder.
- Bu sürüm v1.0.331'in üzerine kaldırmadan güncellenir (aynı kalıcı imza anahtarı).

B Music — duyuru bildirimleri

- Yeni: B Music duyuruları artık bildirim olarak gelir (ücretsiz, Firebase olmadan).
  Uygulama açılırken ve arka planda yaklaşık 4 saatte bir yeni duyuru olup olmadığına bakar.
- Bildirime dokununca uygulama açılır ve duyuru Ayarlar → Bildirimler → Duyurular
  listesinde gösterilir; bağlantı varsa "Bağlantıyı aç" düğmesi çıkar.
- Ayarlar → Bildirimler → "Duyuru bildirimleri" anahtarı ile kapatılabilir (varsayılan açık).
- Uygulamayı kurmadan önce yayımlanmış eski duyurular bildirim olarak gönderilmez.
- Bu sürüm v1.0.328'in üzerine kaldırmadan güncellenir (aynı kalıcı imza anahtarı).

B Music — kalıcı imza anahtarı (güncelleme düzeltmesi)

ÖNEMLİ — tek seferlik (yalnızca v1.0.325 veya daha eski sürümden geliyorsan):
yüklemeden önce eski uygulamayı bir kez kaldır (Ayarlar > Uygulamalar > B_music02 >
Kaldır), sonra bu APK'yı yükle. Önceki sürümler her derlemede farklı, geçici bir
anahtarla imzalanıyordu; Android bu yüzden üzerine güncellemeyi reddediyor ve
"Paket geçersiz" uyarısı veriyordu. Bu sürümden itibaren tüm sürümler aynı kalıcı
anahtarla imzalanır ve kaldırmadan, doğrudan üzerine güncellenir.
Not: Kaldırma işlemi uygulamanın kendi verilerini (ayarlar, favoriler, çalma
listesi kapakları ve uygulama içinden indirilen şarkılar) siler; telefondaki
müzik ve video dosyalarına, Movies/Music/Pictures BMusic klasörlerine dokunmaz.

B Music — video deneyimi güncellemesi

Ana sayfa
- Hızlı Erişim artık en üstte (Son İzlenenler'in eski yerinde); Son İzlenenler onun altında.
- Favori Klasörler bölümü ve altındaki açıklama yazısı kaldırıldı.

Videolar
- Videolar bir kez taranır ve uygulama açık kaldığı sürece hatırlanır; sekmeye her girişte yeniden taranmaz. Yeni eklenen videolar otomatik olarak listeye eklenir. Yenile düğmesi duruyor.
- Video akışı (reels) düğmesi kaldırıldı: bir videoya dokununca doğrudan oynatıcı açılır ve yukarı/aşağı kaydırarak listedeki sonraki/önceki videoya geçilir.
- Klasör adı çipleri yerine yalnızca "Tümü" ve "Dosyalarım" var. Dosyalarım, klasörleri alt alta video sayılarıyla listeler; bir klasöre dokununca o klasörün videoları açılır.

Daha Fazla menüsü
- "Hareket Kontrolleri" kaldırıldı; Ayarlar ve YouTube bağlantısı aç duruyor.

Video oynatıcı (Android oynatıcısı ve uygulama içi oynatıcı aynı şekilde çalışır)
- Tam ekran: kontroller birkaç saniye sonra gizlenir, ekrana dokununca geri gelir.
- Sağ tarafta yukarı/aşağı kaydır: ses; sol tarafta: parlaklık. Yarı saydam gösterge yalnızca kaydırırken görünür; sabit kaydırıcılar kaldırıldı.
- Yatay kaydırma ileri/geri sarar ve süreyi gösterir.
- Altyazı düğmesi yerine "Kes" düğmesi: başlangıç ve bitişi seçip yeni klip olarak kaydet (Movies/BMusic, Android 10+).
- Sağ tarafa basılı tut: bıraktığında normale dönen 2× hız ("2×" göstergesi).
- "İki parmakla yakınlaştır • Çift dokunarak 10 sn sar" yazısı kaldırıldı.
- Kaydırma çakışması: listeden açılan videolarda ekranın sol %30'u parlaklık, sağ %30'u ses, ortadaki %40'ı ise önceki/sonraki videoya geçiş içindir. Tek video açıkken sol yarı parlaklık, sağ yarı sestir.

Notlar: Video listesi uygulama kapanınca yeniden taranır. Bazı biçimler (ör. MPEG-2)
cihazda kesilemeyebilir; bu durumda uyarı gösterilir. Ses hareketi oynatıcının ses
düzeyini değiştirir. GIF ve ekran görüntüleri Pictures/BMusic, klipler Movies/BMusic,
sesler Music/BMusic içine kaydedilir.
