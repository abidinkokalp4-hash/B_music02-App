import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/contact_service.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Gizlilik Politikası',
      icon: Icons.privacy_tip_rounded,
      url: ContactService.privacyUrl,
      sections: [
        _LegalSection(
          '1. Hesap ve reklam yok',
          'B Music hesap, giriş veya sosyal profil gerektirmez ve reklam göstermez. Müzik ve video dosyalarınız telefonunuzdan çıkmaz; hiçbir sunucuya yüklenmez.',
        ),
        _LegalSection(
          '2. Telefonda kalan bilgiler',
          'Favoriler, çalma listeleri, kaldığınız yer, izleme geçmişi, alarmlar ve ayarlar yalnızca telefonunuzda saklanır. Uygulamayı kaldırdığınızda veya Ayarlar > Gizlilik > "Ayarları sıfırla" ile silinir.',
        ),
        _LegalSection(
          '3. Müzik ve video erişimi',
          'Medya izni yalnızca telefonunuzdaki dosyaları listelemek, oynatmak ve sizin başlattığınız kırpma, GIF, ses kaydetme, ekran görüntüsü, taşıma, yeniden adlandırma ve silme işlemleri için kullanılır. Dosya adları ve içerikleri hiçbir yere gönderilmez.',
        ),
        _LegalSection(
          '4. Bildirimler (Firebase Cloud Messaging)',
          'B Music duyurularını gönderebilmek için Google, cihaza özgü rastgele bir bildirim jetonu işler. Ayarlar > Bildirimler > "Duyuru bildirimleri" ile kapatabilirsiniz.',
        ),
        _LegalSection(
          '5. Kullanım istatistikleri ve hata raporları',
          'Google Analytics for Firebase uygulama açılışlarını, ekranları ve bildirim açılmalarını; Firebase Crashlytics çökme ayrıntısını, cihaz modelini, Android ve uygulama sürümünü işler. Reklam kimliği kullanılmaz. Ayarlar > Gizlilik > "Kullanım ve hata raporları" ile ikisini de kapatabilirsiniz.',
        ),
        _LegalSection(
          '6. Öneri Kutusu',
          'Yalnızca siz gönderirseniz: öneri metniniz, isteğe bağlı iletişim bilginiz, uygulama sürümü, Android sürümü ve cihaz modeli Google Cloud Firestore\'da saklanır ve yalnızca geliştirici tarafından okunur.',
        ),
        _LegalSection(
          '7. Paylaşım, güvenlik ve silme',
          'Veriler satılmaz ve reklam için kullanılmaz; Google yalnızca hizmet sağlayıcı olarak işler. Aktarımlar şifrelidir (HTTPS). Öneri Kutusu mesajlarınızın veya diğer verilerin silinmesini e-postayla isteyebilirsiniz.',
        ),
        _LegalSection(
          '8. İletişim',
          'Gizlilik veya veri kullanımıyla ilgili sorularınız için ${ContactService.email} adresinden iletişime geçebilirsiniz. Tam metin (Türkçe / English): ${ContactService.privacyUrl}',
        ),
      ],
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Kullanım Koşulları',
      icon: Icons.gavel_rounded,
      sections: [
        _LegalSection(
          '1. Uygulamanın amacı',
          'B Music; cihazınızdaki müzikleri dinlemek, favorileri ve çalma listelerini yönetmek, dinleme istatistiklerini görüntülemek ve desteklenen çevrim içi kaynaklarda müzik keşfetmek için sunulan bir müzik uygulamasıdır.',
        ),
        _LegalSection(
          '2. Cihazınızdaki içerikler',
          'Telefonunuzdaki müzik dosyalarının kullanım hakkı ve yasal sorumluluğu size aittir. B Music cihazınızdaki dosyaların sahipliğini üstlenmez ve yerel medya dosyalarını kendi adına yayımlamaz.',
        ),
        _LegalSection(
          '3. Çevrim içi kaynaklar',
          'Keşfet bölümünde gösterilen dış bağlantılar ve içerikler ilgili hizmet sağlayıcıların kurallarına tabidir. B Music üçüncü taraf servislerin erişilebilirliğini, içerik devamlılığını veya lisans durumunu garanti etmez.',
        ),
        _LegalSection(
          '4. Telif hakları',
          'Telif hakkıyla korunan içerikleri yalnızca hukuka ve hak sahibinin izinlerine uygun şekilde kullanmalısınız. Uygulama, telifli içeriğin izinsiz dağıtımını teşvik etmek amacıyla kullanılamaz.',
        ),
        _LegalSection(
          '5. Uygulama değişiklikleri',
          'Özellikler güvenlik, platform gereksinimleri, teknik sınırlamalar veya yasal yükümlülükler nedeniyle değiştirilebilir, kaldırılabilir ya da güncellenebilir.',
        ),
        _LegalSection(
          '6. Sorumluluk sınırı',
          'Cihaz, işletim sistemi, medya dosyası biçimi veya üçüncü taraf hizmetlerden kaynaklanan kesintiler oluşabilir. Kullanıcı önemli müzik dosyalarının ve cihaz verilerinin kendi yedeğini tutmaktan sorumludur.',
        ),
        _LegalSection(
          '7. İletişim',
          'Destek ve yasal bildirimler için ${ContactService.email} adresinden iletişime geçebilirsiniz.',
        ),
      ],
    );
  }
}

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'İçerik ve Kaynak Kuralları',
      icon: Icons.library_music_rounded,
      sections: [
        _LegalSection(
          'Yasal içeriği kullan',
          'Müzik ve diğer medya içeriklerini yalnızca sahip olduğunuz veya kullanma hakkınız bulunan koşullarda kullanın.',
        ),
        _LegalSection(
          'Kaynak kurallarına uy',
          'Wikimedia ve diğer dış hizmetleri kullanırken ilgili platformun kullanım koşulları ve içerik politikaları geçerlidir.',
        ),
        _LegalSection(
          'Cihaz güvenliğini koru',
          'Bilinmeyen veya güvenilmeyen kaynaklardan indirilen dosyaların güvenliğini kontrol etmek kullanıcının sorumluluğundadır.',
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.icon,
    required this.sections,
    this.url,
  });

  final String title;
  final String? url;
  final IconData icon;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: AppColors.accentSoft, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'B Music',
                        style: TextStyle(
                          color: AppColors.accentSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Son güncelleme: 7 Ekim 2026',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          if (url != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(url!),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Tam metni aç (web)'),
              ),
            ),
          ],
          const SizedBox(height: 22),
          ...sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.55,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}
