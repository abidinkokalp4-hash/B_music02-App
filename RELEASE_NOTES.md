B_music02 1.0

- Release APK içinde medya kontrol simgeleri korunur; Android 13 ve üzerindeki bildirim ve kilit ekranı oynatma kontrolü hatası düzeltilir.
- APK doğrulaması artık bildirim simgesine ek olarak oynat, duraklat, önceki, sonraki, durdur ve ileri/geri simgelerini denetler.
- Değişmeyen sıra, şarkı ve oynatma durumları Android medya servisine tekrar gönderilmez. Oynat/duraklat geçişleri, yeni şarkılar ve sıra değişiklikleri aktarılmaya devam eder.
- Android medya durumu, oynatıcının atomik olayından aktarılır; çalma ve yükleme değişiklikleri gecikmiş değerlerden okunmaz.
- Kapak resmi sonradan yüklendiğinde tespit edilen şarkı süresi korunur; sıradan ilerleme olayları kapak resmini veya süreyi sıfırlamaz.
- Ekolayzerin ses oturumu hazırlanma sırası düzeltilir. Ses efekti kullanılamayan cihazlarda müzik oynatma devam eder.
- Yenilenen ana sayfa, müzik arşivi, mini oynatıcı ve tam ekran oynatıcı.
- Türkçe karakterleri destekleyen arama; sanatçı, albüm, klasör ve favori görünümleri.
- Sonraki çal, sıraya ekle, sürükleyerek sırala ve sıradan çıkar.
- Çalma listesi oluşturma, şarkı seçme, ad değiştirme ve sıralama.
- Kayıtlı sıra ve kaldığın yerden devam; yeniden açılışta otomatik çalma yapılmaz.
- Uyku zamanlayıcısı ve geçerli şarkının sonunda duraklatma.
- Arka plan ve kilit ekranı için ortak Android medya servisi.
- Mevcut video oynatıcı, ekolayzer, çevrimiçi keşif ve indirilen müzikler korunur.
- Çevrimiçi sonuçlar yüklenemediğinde YouTube aramasına devam etme ve izinli müzik bulma seçenekleri.

Doğrulama: Flutter analizi, medya/arama/sıra/zamanlayıcı regresyonları, küçük ekran ve büyük yazı testleri, release APK manifesti ve bildirim simgesi. Fiziksel Android cihaz testi yapılmamıştır.
