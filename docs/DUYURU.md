# Duyuru (bildirim) nasıl gönderilir?

B Music, depo kökündeki `announcements.json` dosyasını okuyarak tüm kullanıcılara
ücretsiz duyuru bildirimi gösterir. Firebase veya sunucu gerekmez.

Uygulamanın okuduğu adres:
`https://raw.githubusercontent.com/abidinkokalp4-hash/B_music02-App/main/announcements.json`

## Yeni duyuru ekleme

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

## Alanlar

| Alan | Zorunlu | Açıklama |
| --- | --- | --- |
| `id` | Evet | Her duyuru için **benzersiz** ve **değişmeyen** kimlik (ör. `2026-10-10-1`). Aynı kimlik bir telefonda yalnızca bir kez bildirilir. |
| `title` | Evet | Bildirim başlığı (en fazla 120 karakter). |
| `body` | Hayır | Bildirim metni (en fazla 1000 karakter). |
| `url` | Hayır | Duyurular ekranındaki "Bağlantıyı aç" düğmesi. Yalnızca `https://` adresleri kabul edilir. |
| `createdAt` | Önerilir | ISO tarih-saat, ör. `2026-10-10T18:00:00+03:00`. Uygulamayı bu tarihten **sonra** kuran kişilere bu duyuru bildirim olarak gelmez (yalnızca listede görünür). |

## Ne zaman görünür?

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
  ya da Android bildirim iznini vermezse bildirim gelmez; duyurular yine listede görünür.
- Xiaomi/HyperOS gibi pil tasarrufu agresif telefonlarda arka plan kontrolü
  gecikebilir; uygulama açılınca duyuru yine gelir.

Depo herkese açık olduğu için duyurulara kişisel bilgi yazma.
