import 'package:flutter/material.dart';

import '../../core/services/contact_service.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Gizlilik Politikası',
      icon: Icons.privacy_tip_rounded,
      sections: [
        _LegalSection(
          '1. Hesap gerektirmeyen kullanım',
          'B_music02 bu sürümde kullanıcı hesabı, e-posta ile giriş veya sosyal profil gerektirmez. Uygulamayı temel müzik özellikleri için hesap oluşturmadan kullanabilirsiniz.',
        ),
        _LegalSection(
          '2. Cihazda saklanan veriler',
          'Favorileriniz, oluşturduğunuz çalma listeleri, dinleme geçmişi, dinleme sayıları, tema tercihi ve benzeri kişisel uygulama tercihleri cihazınızda yerel olarak saklanır. Bu bilgiler hesabınıza bağlı bir sosyal profil oluşturmak için kullanılmaz.',
        ),
        _LegalSection(
          '3. Müzik dosyalarına erişim',
          'Telefondaki müzikleri gösterebilmek için Android veya iOS tarafından sağlanan medya erişim izni istenebilir. B_music02 yalnızca müzik kütüphanesini listelemek, kapak görsellerini göstermek ve seçtiğiniz parçaları oynatmak amacıyla bu erişimi kullanır.',
        ),
        _LegalSection(
          '4. Bildirim izni',
          'Bildirim izni, desteklenen cihazlarda medya oynatma kontrollerini ve oynatmayla ilgili sistem bildirimlerini göstermek için kullanılabilir. İzin verilmemesi uygulamanın temel müzik kütüphanesi kullanımını engellemez.',
        ),
        _LegalSection(
          '5. İnternet ve üçüncü taraf kaynaklar',
          'Keşfet gibi çevrim içi özellikler kullanıldığında YouTube, Wikimedia veya benzeri dış hizmetlerden herkese açık müzik ve içerik bilgileri alınabilir. Bu hizmetlerin kendi gizlilik ve kullanım koşulları geçerlidir.',
        ),
        _LegalSection(
          '6. Reklam ve veri satışı',
          'B_music02 kişisel verilerinizi reklam verenlere satmaz. Uygulamanın temel müzik kütüphanesi ve yerel dinleme tercihleri pazarlama profili oluşturmak amacıyla kullanılmaz.',
        ),
        _LegalSection(
          '7. Verileri silme',
          'Yerel olarak tutulan favoriler, çalma listeleri ve uygulama tercihleri uygulama verileri temizlendiğinde veya uygulama kaldırıldığında cihazdan silinebilir. Bazı medya dosyaları uygulamadan bağımsız olarak telefonunuzda kalmaya devam eder.',
        ),
        _LegalSection(
          '8. İletişim',
          'Gizlilik veya veri kullanımıyla ilgili sorularınız için ${ContactService.advertisingEmail} adresinden iletişime geçebilirsiniz.',
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
          'B_music02; cihazınızdaki müzikleri dinlemek, favorileri ve çalma listelerini yönetmek, dinleme istatistiklerini görüntülemek ve desteklenen çevrim içi kaynaklarda müzik keşfetmek için sunulan bir müzik uygulamasıdır.',
        ),
        _LegalSection(
          '2. Cihazınızdaki içerikler',
          'Telefonunuzdaki müzik dosyalarının kullanım hakkı ve yasal sorumluluğu size aittir. B_music02 cihazınızdaki dosyaların sahipliğini üstlenmez ve yerel medya dosyalarını kendi adına yayımlamaz.',
        ),
        _LegalSection(
          '3. Çevrim içi kaynaklar',
          'Keşfet bölümünde gösterilen dış bağlantılar ve içerikler ilgili hizmet sağlayıcıların kurallarına tabidir. B_music02 üçüncü taraf servislerin erişilebilirliğini, içerik devamlılığını veya lisans durumunu garanti etmez.',
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
          'Destek ve yasal bildirimler için ${ContactService.advertisingEmail} adresinden iletişime geçebilirsiniz.',
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
          'YouTube, Wikimedia ve diğer dış hizmetleri kullanırken ilgili platformun kullanım koşulları ve içerik politikaları geçerlidir.',
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
  });

  final String title;
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
                        'B_music02',
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
            'Son güncelleme: 13 Eylül 2026',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
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
