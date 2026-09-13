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
          '1. Toplanan bilgiler',
          'B_music02; hesap oluşturma ve uygulama özelliklerini çalıştırmak için kullanıcı adı, görünen ad, profil bilgileri, kullanıcı tarafından yüklenen içerikler, sohbet ve topluluk etkileşimleri ile izin verilmesi hâlinde cihazdaki müzik dosyalarına erişim gibi verileri işler. Şifreniz uygulama tarafından düz metin olarak saklanmaz; kimlik doğrulama Supabase Auth üzerinden yürütülür.',
        ),
        _LegalSection(
          '2. İzinler',
          'Bildirim, mikrofon, kamera ve cihazdaki müzik dosyalarına erişim izinleri yalnızca ilgili özellik kullanıldığında veya kullanıcı izin merkezinde açıkça talep ettiğinde istenir. Fotoğraf seçimi mümkün olduğunda sistem fotoğraf seçicisi üzerinden yapılır ve tüm galeriye sürekli erişim talep edilmez.',
        ),
        _LegalSection(
          '3. Verilerin kullanım amacı',
          'Veriler; hesabı işletmek, müzik ve sosyal özellikleri sunmak, mesajlaşmayı sağlamak, topluluk güvenliğini korumak, şikâyetleri incelemek, kötüye kullanımı önlemek ve uygulama deneyimini geliştirmek amacıyla kullanılır.',
        ),
        _LegalSection(
          '4. Paylaşım ve üçüncü taraf hizmetleri',
          'B_music02 altyapıda Supabase gibi hizmet sağlayıcıları kullanabilir. Kullanıcı verileri reklam verenlere satılmaz. Yasal zorunluluklar veya güvenlik gereklilikleri dışında kişisel veriler üçüncü taraflarla amaç dışı paylaşılmaz.',
        ),
        _LegalSection(
          '5. Kullanıcı içerikleri',
          'Topluluk gönderileri, yorumlar, sohbet mesajları ve kullanıcı tarafından paylaşılan diğer içerikler ilgili özelliğin niteliğine göre diğer kullanıcılara görünebilir. Şikâyet edilen içerikler moderasyon amacıyla incelenebilir.',
        ),
        _LegalSection(
          '6. Hesabın ve verilerin silinmesi',
          'Ayarlar ve Gizlilik bölümündeki Hesabımı Sil seçeneği kullanılarak hesap silme işlemi başlatılabilir. Silme tamamlandığında hesabınız ve hesaba bağlı uygulama verileri kalıcı olarak kaldırılır. Yasal olarak saklanması zorunlu kayıtlar varsa yalnızca gerekli süre boyunca tutulabilir.',
        ),
        _LegalSection(
          '7. Güvenlik',
          'Yetkisiz erişimi azaltmak için erişim kuralları, oturum doğrulaması ve Supabase Row Level Security politikaları kullanılır. İnternet üzerinden yapılan hiçbir aktarımın mutlak güvenliği garanti edilemez.',
        ),
        _LegalSection(
          '8. İletişim',
          'Gizlilik veya veri talepleri için ${ContactService.advertisingEmail} adresinden iletişime geçebilirsiniz.',
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
          '1. Hizmetin kullanımı',
          'B_music02 müzik, topluluk ve mesajlaşma özellikleri sunar. Uygulamayı kullanarak yürürlükteki mevzuata ve bu koşullara uymayı kabul edersiniz.',
        ),
        _LegalSection(
          '2. Hesap güvenliği',
          'Hesabınız üzerinden yapılan işlemlerin güvenliğini korumak sizin sorumluluğunuzdadır. Başkasının hesabını kullanmak, kimliğe bürünmek veya yetkisiz erişim girişiminde bulunmak yasaktır.',
        ),
        _LegalSection(
          '3. Yasak içerikler',
          'Tehdit, taciz, nefret söylemi, cinsel istismar içeriği, dolandırıcılık, kişisel bilgilerin izinsiz paylaşılması, yasa dışı içerik, spam ve başkalarının fikrî mülkiyet haklarını ihlal eden içerikler yasaktır.',
        ),
        _LegalSection(
          '4. Telif ve müzik içerikleri',
          'Kullanıcı yalnızca paylaşma veya kullanma hakkına sahip olduğu içerikleri yüklemelidir. B_music02 izinsiz telifli müziğin dağıtımı için kullanılamaz. Hak ihlali bildirimleri incelenebilir ve ilgili içerik kaldırılabilir.',
        ),
        _LegalSection(
          '5. Moderasyon',
          'B_music02, topluluk güvenliğini korumak için içerikleri kaldırabilir, raporları inceleyebilir, özellik erişimini kısıtlayabilir, hesapları geçici olarak askıya alabilir veya ciddi ihlallerde kalıcı olarak engelleyebilir.',
        ),
        _LegalSection(
          '6. Şikâyet ve engelleme',
          'Kullanıcılar uygunsuz içerikleri veya kullanıcıları uygulama içinden bildirebilir ve diğer kullanıcıları engelleyebilir. Kötü niyetli veya tekrarlanan sahte şikâyetler de kötüye kullanım olarak değerlendirilebilir.',
        ),
        _LegalSection(
          '7. Hizmet değişiklikleri',
          'Özellikler güvenlik, yasal yükümlülükler veya teknik gereksinimler nedeniyle güncellenebilir. Önemli değişiklikler uygulama içinde duyurulabilir.',
        ),
        _LegalSection(
          '8. İletişim',
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
      title: 'Topluluk Kuralları',
      icon: Icons.groups_2_rounded,
      sections: [
        _LegalSection(
          'Saygılı ol',
          'Hakaret, tehdit, taciz, nefret söylemi, hedef gösterme veya bir kullanıcıyı yıldırmaya yönelik davranışlara izin verilmez.',
        ),
        _LegalSection(
          'Güvenli içerik paylaş',
          'Yasa dışı, şiddeti teşvik eden, cinsel istismar içeren, dolandırıcılık amacı taşıyan veya kişisel bilgileri ifşa eden içerikler paylaşmayın.',
        ),
        _LegalSection(
          'Telif haklarına uy',
          'Yalnızca paylaşma hakkına sahip olduğunuz müzik, video, fotoğraf ve diğer içerikleri yükleyin.',
        ),
        _LegalSection(
          'Spam yapma',
          'Tekrarlayan reklamlar, yanıltıcı bağlantılar, otomatik mesajlar ve topluluğu bozacak toplu paylaşımlar kaldırılabilir.',
        ),
        _LegalSection(
          'Sorunları bildir',
          'Uygunsuz bir içerik veya kullanıcı gördüğünüzde Şikâyet Et seçeneğini kullanın. Acil güvenlik durumlarında ilgili resmi mercilere başvurun.',
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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Son güncelleme: 13 Eylül 2026',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    section.body,
                    style: const TextStyle(height: 1.55, fontSize: 12),
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
