# Duyuru (bildirim) nasıl gönderilir?

İki yol birlikte çalışır:

1. **Anlık bildirim (Firebase Cloud Messaging, ücretsiz Spark planı):** saniyeler
   içinde tüm telefonlara gider (FCM konusu `all`).
2. **`announcements.json` (yedek yol):** uygulama açılınca ve arka planda yaklaşık
   4 saatte bir bu dosyaya bakar. Anlık bildirimi alamayan telefonlar (eski sürüm,
   pil kısıtlaması, Google Play hizmetleri olmayan cihaz) duyuruyu buradan alır.

Anlık bildirim, uygulamanın anlık bildirim destekli sürümünden (v1.0.331'den sonraki
ilk sürüm) itibaren çalışır; daha eski sürümler duyuruyu yalnızca 2. yoldan alır.

Aynı duyuru iki yoldan da aynı `id` ile gelir; telefon bir `id`'yi **yalnızca bir kez**
bildirir ve Ayarlar → Bildirimler → **Duyurular** listesine ekler.

## Telefondan anlık bildirim gönder (önerilen)

1. GitHub uygulamasında (veya tarayıcıda github.com) **abidinkokalp4-hash/B_music02-App**
   deposunu aç.
2. **Actions** sekmesine gir → listeden **Send notification**'ı seç.
3. **Run workflow**'a dokun ve doldur:
   - **Başlık** (zorunlu, en fazla 120 karakter)
   - **Metin** (isteğe bağlı, en fazla 1000 karakter)
   - **Bağlantı** (isteğe bağlı, `https://` ile başlamalı; bildirime dokununca açılır)
   - **Sadece dene** kutusunu boş bırak (işaretlersen yalnızca doğrulanır, hiçbir şey gönderilmez).
4. Yeşil **Run workflow** düğmesine bas. Yaklaşık yarım dakika içinde yeşil tik
   çıkar: bildirim gönderildi ve aynı duyuru `announcements.json`'a eklendi
   (`Duyuru: <id> [skip ci]` commit'i; yeni APK derlenmez).

İş akışı Google'a **anahtarsız** bağlanır (GitHub OIDC → Workload Identity Federation →
`fcm-sender@bmusic02-app.iam.gserviceaccount.com`, yalnızca Firebase Cloud Messaging
gönderme yetkisi). Depoda gizli anahtar yoktur; Google tarafı yalnızca bu deponun
`main` dalındaki `send-notification.yml` dosyasına güvenir.

Bilgisayardan (Firebase CLI girişi olan makinede) aynı işi `tool/send_push.py` yapar:

```sh
python3 tool/send_push.py --title "Yeni sürüm" --body "Güncelleme hazır" --dry-run   # yalnızca doğrula
python3 tool/send_push.py --title "Test" --token <tek cihazın FCM jetonu>             # tek cihaza test
python3 tool/send_push.py --title "Yeni sürüm" --body "..." --record announcements.json  # herkese + dosyaya ekle
```

`--record` kullanırsan `announcements.json` değişikliğini `[skip ci]` ile commit edip push et.

Anlık bildirim mesajı yalnızca veri (data) içerir: `id`, `title`, `body`, isteğe bağlı
`url`, `createdAt`. Firebase konsolundan "notification" olarak gönderilen mesajlar da
çalışır (uygulama kapalıyken Android gösterir, dokununca Duyurular açılır), ama
`announcements.json`'a eklenmez; bu yüzden GitHub Actions yolu önerilir.

## announcements.json'u elle düzenleme

B Music, depo kökündeki `announcements.json` dosyasını okuyarak tüm kullanıcılara
ücretsiz duyuru bildirimi gösterir. Sunucu gerekmez. ("Send notification" iş akışı
bu dosyayı senin yerine günceller; elle düzenlersen anlık bildirim gitmez, duyuru
telefonlara bir sonraki kontrolde gelir.)

Uygulamanın okuduğu adres:
`https://raw.githubusercontent.com/abidinkokalp4-hash/B_music02-App/main/announcements.json`

### Yeni duyuru ekleme

1. GitHub'da depoyu aç → `main` dalındaki `announcements.json` dosyası → kalem (Düzenle) simgesi.
2. `announcements` listesine **en üste** yeni bir kayıt ekle:

```json
{
  "announcements": [
    {
      "id": "2026-10-10-1",
      "title": "Yeni sürüm hazır",
      "body": "v1.0.330 yayında: video oynatıcıda yenilikler var.",
      "url": "https://github.com/abidinkokalp4-hash/B_music02-App/releases/latest",
      "createdAt": "2026-10-10T18:00:00+03:00"
    }
  ]
}
```

3. "Commit changes" ile `main` dalına kaydet. Birden fazla duyuru varsa kayıtları
   virgülle ayır.

### Alanlar

| Alan | Zorunlu | Açıklama |
| --- | --- | --- |
| `id` | Evet | Her duyuru için **benzersiz** ve **değişmeyen** kimlik (ör. `2026-10-10-1`). Aynı kimlik bir telefonda yalnızca bir kez bildirilir. |
| `title` | Evet | Bildirim başlığı (en fazla 120 karakter). |
| `body` | Hayır | Bildirim metni (en fazla 1000 karakter). |
| `url` | Hayır | Duyurular ekranındaki "Bağlantıyı aç" düğmesi. Yalnızca `https://` adresleri kabul edilir. |
| `createdAt` | Önerilir | ISO tarih-saat, ör. `2026-10-10T18:00:00+03:00`. Uygulamayı bu tarihten **sonra** kuran kişilere bu duyuru bildirim olarak gelmez (yalnızca listede görünür). |

## Ne zaman görünür?

- Anlık bildirim: telefon internete bağlıyken genellikle birkaç saniye içinde.
  Telefon kapalı/çevrimdışıysa FCM mesajı 7 gün saklar ve bağlanınca teslim eder.

- Uygulama açıldığında ve öne geldiğinde (en fazla 15 dakikada bir) kontrol edilir.
- Arka planda yaklaşık **4 saatte bir** (internet varken) Android WorkManager ile kontrol edilir.
- GitHub'ın önbelleği nedeniyle değişikliğin görünmesi birkaç dakika sürebilir.
- Bir kontrolde en fazla 3 yeni duyuru bildirim olarak gösterilir; diğerleri
  Ayarlar → Bildirimler → **Duyurular** listesinde görünür.
- Bildirime dokununca uygulama açılır ve Duyurular listesinde o duyuru vurgulanır.

## Kurallar ve ipuçları

- Bir duyurunun `id` değerini sonradan değiştirme; değiştirirsen herkese yeniden bildirilir.
- Duyuruyu geri almak için kaydı listeden silmen yeterli (gönderilmiş bildirimler telefonlarda kalır).
- JSON bozuksa uygulama sessizce yok sayar; kaydetmeden önce
  [jsonlint.com](https://jsonlint.com) gibi bir araçla kontrol edebilirsin.
- Kullanıcı Ayarlar → Bildirimler → **Duyuru bildirimleri** anahtarını kapatırsa
  telefon `all` konusundan çıkar ve hiçbir yoldan bildirim gelmez; Android bildirim
  iznini vermezse de bildirim gelmez. Duyurular yine listede görünür.
- Xiaomi/HyperOS gibi pil tasarrufu agresif telefonlarda arka plan kontrolü
  gecikebilir; uygulama açılınca duyuru yine gelir.

Depo herkese açık olduğu için duyurulara kişisel bilgi yazma.
