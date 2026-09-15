import 'package:flutter/material.dart';

import '../services/player_preferences.dart';

/// Exact UI labels only. Device filenames, artist names and other user data are
/// rendered with ordinary Text widgets and are never translated.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textDirection,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PlayerPreferences.instance,
    builder: (c, _) {
      final lang = PlayerPreferences.instance.text('language', 'tr');
      return Text(
        translate(data, lang),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textDirection:
            textDirection ??
            (['ar', 'ckb'].contains(lang) ? TextDirection.rtl : null),
      );
    },
  );
}

String translate(String text, String language) {
  if (language == 'tr') return text;
  final i = ['en', 'ku', 'ckb', 'ar'].indexOf(language);
  return i < 0 ? text : (_translations[text]?[i] ?? text);
}

final Map<String, List<String>> _translations = {
  for (final row in _rows.trim().split('\n'))
    row.split('|').first: row.split('|').skip(1).toList(),
};
const _rows = '''
Ana Sayfa|Home|Destpêk|سەرەکی|الرئيسية
Müzik|Music|Muzîk|مۆسیقا|الموسيقى
Video|Video|Vîdyo|ڤیدیۆ|الفيديو
Listeler|Playlists|Lîste|لیستەکان|قوائم التشغيل
Ayarlar|Settings|Mîheng|ڕێکخستنەکان|الإعدادات
Görünüm ve Tema|Appearance and Theme|Dîtin û Tema|ڕووکار و ڕووپۆش|المظهر والسمة
Ses Ayarları|Audio Settings|Mîhengên Deng|ڕێکخستنی دەنگ|إعدادات الصوت
Ekolayzer|Equalizer|Ekualayzer|یەکسانکەری دەنگ|معادل الصوت
Uyku Zamanlayıcısı|Sleep Timer|Demjimêra Xewê|کاتژمێری خەوتن|مؤقت النوم
Medya Tarama|Media Scan|Lêgerîna Medyayê|گەڕان بۆ میدیا|فحص الوسائط
Bildirim ve Kilit Ekranı Kontrolleri|Notification and Lock Screen Controls|Kontrolên Agahdarî û Ekrana Kilîtkirî|کۆنترۆڵی ئاگادارکردنەوە و شاشەی قوفڵ|التحكم بالإشعارات وشاشة القفل
Dil|Language|Ziman|زمان|اللغة
Gelişmiş Ayarlar|Advanced Settings|Mîhengên Pêşketî|ڕێکخستنە پێشکەوتووەکان|الإعدادات المتقدمة
Uygulama Hakkında|About the App|Derbarê Sepanê|دەربارەی بەرنامە|حول التطبيق
Şimdi Çalıyor|Now Playing|Niha Tê Lêdan|ئێستا لێدەدرێت|يُشغّل الآن
Son Çalınanlar|Recently Played|Dawî Lêdayî|دوایین لێدراوەکان|تم تشغيلها مؤخراً
Son Dinlenenler|Recently Played|Dawî Lêdayî|دوایین لێدراوەکان|تم تشغيلها مؤخراً
En Çok Dinlenenler|Most Played|Herî Zêde Lêdayî|زۆرترین لێدراوەکان|الأكثر تشغيلاً
Favoriler|Favorites|Bijarte|دڵخوازەکان|المفضلة
Tümü|All|Hemû|هەموو|الكل
İletişim|Contact|Têkilî|پەیوەندی|اتصل بنا
Tamam|OK|Baş e|باشە|حسناً
Vazgeç|Cancel|Betal bike|هەڵوەشاندنەوە|إلغاء
Kaydet|Save|Tomar bike|پاشەکەوتکردن|حفظ
Sil|Delete|Jê bibe|سڕینەوە|حذف
Oynat|Play|Lê bide|لێدان|تشغيل
Paylaş|Share|Parve bike|هاوبەشکردن|مشاركة
Dosya bilgileri|File details|Agahiyên Pelê|زانیاری پەڕگە|تفاصيل الملف
Videolarım|My Videos|Vîdyoyên Min|ڤیدیۆکانم|فيديوهاتي
Cihazınızdaki tüm videolar|All videos on your device|Hemû vîdyoyên amûra te|هەموو ڤیدیۆکانی ئامێرەکەت|جميع فيديوهات جهازك
Video bulunamadı|No videos found|Vîdyo nehat dîtin|هیچ ڤیدیۆیەک نەدۆزرایەوە|لم يتم العثور على فيديوهات
Video erişimine izin ver|Allow video access|Destûra vîdyoyan bide|ڕێگە بە دەستگەیشتن بە ڤیدیۆ بدە|السماح بالوصول للفيديو
Yeni → Eski|Newest → Oldest|Nû → Kevn|نوێ → کۆن|الأحدث ← الأقدم
Eski → Yeni|Oldest → Newest|Kevn → Nû|کۆن → نوێ|الأقدم ← الأحدث
En Büyük Boyut|Largest size|Mezinahiya herî mezin|گەورەترین قەبارە|الأكبر حجماً
En Küçük Boyut|Smallest size|Mezinahiya herî biçûk|بچووکترین قەبارە|الأصغر حجماً
En Uzun Süre|Longest duration|Dema herî dirêj|درێژترین ماوە|الأطول مدة
En Kısa Süre|Shortest duration|Dema herî kurt|کورتترین ماوە|الأقصر مدة
İzinler|Permissions|Destûr|ڕێگەپێدانەکان|الأذونات
Müziğin için gereken izinler|Permissions for your music|Destûrên ji bo muzîka te|ڕێگەپێدان بۆ مۆسیقاکەت|أذونات الموسيقى
Tüm izinleri ver|Grant all permissions|Hemû destûran bide|هەموو ڕێگەپێدانەکان بدە|منح جميع الأذونات
Telefonundaki müzikler|Music on your phone|Muzîka telefona te|مۆسیقای تەلەفۆنەکەت|موسيقى هاتفك
Telefonundaki videolar|Videos on your phone|Vîdyoyên telefona te|ڤیدیۆکانی تەلەفۆنەکەت|فيديوهات هاتفك
Müzik bildirimi|Music notification|Agahdariya muzîkê|ئاگادارکردنەوەی مۆسیقا|إشعار الموسيقى
Arka planda çalışma|Background playback|Lêdana li paşperdeyê|لێدان لە پاشبنەما|التشغيل في الخلفية
Kilit ekranı kontrolleri|Lock screen controls|Kontrolên ekrana kilîtkirî|کۆنترۆڵی شاشەی قوفڵ|أزرار شاشة القفل
Telefon ayarlarını aç|Open phone settings|Mîhengên telefonê veke|ڕێکخستنی تەلەفۆن بکەرەوە|فتح إعدادات الهاتف
Uygulamaya devam et|Continue to app|Bi sepanê bidomîne|بەردەوامبە بۆ بەرنامە|المتابعة للتطبيق
Koyu Tema|Dark Theme|Temaya Tarî|ڕووپۆشی تاریک|السمة الداكنة
Açık Tema|Light Theme|Temaya Ronî|ڕووپۆشی ڕووناک|السمة الفاتحة
Sistem Teması|System Theme|Temaya Pergalê|ڕووپۆشی سیستەم|سمة النظام
Renk Seçenekleri|Accent Colors|Vebijêrkên Rengan|هەڵبژاردەکانی ڕەنگ|خيارات الألوان
Dinamik Renkler|Dynamic Colors|Rengên Dînamîk|ڕەنگە گۆڕاوەکان|الألوان الديناميكية
Aylık Duvar Kağıdı|Monthly Wallpaper|Paşperdeya Mehane|پاشبنەمای مانگانە|خلفية شهرية
Uygulama simgesi rengi|App Icon Color|Rengê Îkona Sepanê|ڕەنگی هێمای بەرنامە|لون أيقونة التطبيق
Ses Kalitesi|Audio Quality|Kalîteya Deng|کوالیتی دەنگ|جودة الصوت
Çalma Ayarları|Playback Settings|Mîhengên Lêdanê|ڕێکخستنی لێدان|إعدادات التشغيل
Hareketlerle ses kontrolü|Gesture Volume Control|Kontrola deng bi tevgerê|کۆنترۆڵی دەنگ بە جووڵە|التحكم بالصوت بالإيماءات
Kulaklık takılınca devam et|Resume when headphones connect|Bi girêdana guhikan bidomîne|بەردەوامبە کاتێک گوێگر دەبەسترێت|استئناف عند توصيل السماعات
Varsayılan Ses Seviyesi|Default Volume|Asta Dengê Bingehîn|ئاستی دەنگی بنەڕەتی|مستوى الصوت الافتراضي
Ön Ayarlar|Presets|Mîhengên Amade|ڕێکخستنە ئامادەکان|الإعدادات المسبقة
Yeniden dene|Retry|Dîsa biceribîne|دووبارە هەوڵبدەرەوە|إعادة المحاولة
Özel süre seç|Custom Duration|Demeke taybet hilbijêre|ماوەی تایبەت هەڵبژێرە|اختيار مدة مخصصة
Başlat|Start|Dest pê bike|دەستپێبکە|بدء
Müzik Tara|Scan Music|Li Muzîkê Bigere|گەڕان بۆ مۆسیقا|فحص الموسيقى
Video Tara|Scan Videos|Li Vîdyoyan Bigere|گەڕان بۆ ڤیدیۆ|فحص الفيديو
Gizli dosyaları da tara|Include Hidden Files|Pelên veşartî jî bigere|پەڕگە شاراوەکانیش بگەڕێ|تضمين الملفات المخفية
Taramayı Başlat|Start Scan|Lêgerînê Dest Pê Bike|دەست بە گەڕان بکە|بدء الفحص
Medya Bildirimleri|Media Notifications|Agahdariyên Medyayê|ئاگادارکردنەوەی میدیا|إشعارات الوسائط
Kilit Ekranı Kontrolleri|Lock Screen Controls|Kontrolên Ekrana Kilîtkirî|کۆنترۆڵی شاشەی قوفڵ|أزرار شاشة القفل
Tüm Bildirimlere İzin Ver|Allow Notifications|Destûra Agahdariyan Bide|ڕێگە بە ئاگادارکردنەوە بدە|السماح بالإشعارات
Başlangıç ekranı|Start Screen|Ekrana Destpêkê|شاشەی دەستپێک|شاشة البداية
Önbelleği temizle|Clear Cache|Bîra demkî paqij bike|کاش پاک بکەرەوە|مسح الذاكرة المؤقتة
Veritabanını yenile|Refresh Media Index|Danegehê Nû Bike|نوێکردنەوەی بنکەدراوە|تحديث فهرس الوسائط
İçe / Dışa aktar|Import / Export|Têxe / Derxe|هاوردە / هەناردە|استيراد / تصدير
Arka planda çalıştır|Play in Background|Li Paşperdeyê Lê Bide|لێدان لە پاشبنەما|تشغيل في الخلفية
Sıfırla|Reset|Vegere Destpêkê|ڕێکخستنەوە|إعادة تعيين
Sürüm|Version|Guherto|وەشان|الإصدار
Gizlilik Politikası|Privacy Policy|Siyaseta Nepenîtiyê|سیاسەتی تایبەتمەندی|سياسة الخصوصية
Kullanım Koşulları|Terms of Use|Mercên Bikaranînê|مەرجەکانی بەکارهێنان|شروط الاستخدام
Açık Kaynak Lisansları|Open Source Licenses|Lîsansên Çavkaniya Vekirî|مۆڵەتی سەرچاوە کراوە|تراخيص المصادر المفتوحة
Listelerim|My Playlists|Lîsteyên Min|لیستەکانم|قوائم تشغيلي
Yeni Liste|New Playlist|Lîsteya Nû|لیستی نوێ|قائمة جديدة
Çalma Listelerim|My Playlists|Lîsteyên Min|لیستەکانم|قوائم تشغيلي
Liste adı|Playlist Name|Navê Lîsteyê|ناوی لیست|اسم القائمة
Yeniden adlandır|Rename|Navê Nû Bide|ناو بگۆڕە|إعادة تسمية
Listeyi sil|Delete Playlist|Lîsteyê Jê Bibe|لیست بسڕەوە|حذف القائمة
Listeden çıkar|Remove from Playlist|Ji Lîsteyê Derxe|لە لیستەکە لایببە|إزالة من القائمة
Favorilere ekle|Add to Favorites|Li Bijarteyan Zêde Bike|زیادکردن بۆ دڵخوازەکان|إضافة إلى المفضلة
Favorilerden çıkar|Remove from Favorites|Ji Bijarteyan Derxe|لە دڵخوازەکان لایببە|إزالة من المفضلة
''';
