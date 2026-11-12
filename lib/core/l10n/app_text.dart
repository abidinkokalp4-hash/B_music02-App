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
    this.strutStyle,
    this.textScaler,
    this.semanticsLabel,
    this.textWidthBasis,
    this.locale,
  });
  final StrutStyle? strutStyle;
  final TextScaler? textScaler;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final Locale? locale;
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
        strutStyle: strutStyle,
        textScaler: textScaler,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        locale: locale,
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

/// Template helper: keys use {0}, {1}, ... placeholders.
String translateFormat(String template, String language, List<Object?> args) {
  var out = translate(template, language);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i]}');
  }
  return out;
}

String tf(String template, List<Object?> args) => translateFormat(
    template, PlayerPreferences.instance.text('language', 'tr'), args);


final Map<String, List<String>> _translations = {
  for (final row in _rows.trim().split('\n'))
    if (row.split('|').length == 5)
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
Adını değiştir|Rename|Navê biguherîne|گۆڕینی ناو|إعادة التسمية
Alarm ekle|Add alarm|Alarmê zêde bike|زیادکردنی ئاگادارکەرەوە|إضافة منبه
Alarm şarkısı|Alarm song|Strana alarmê|گۆرانی ئاگادارکەرەوە|أغنية المنبه
Alarmlar ve hatırlatıcılar|Alarms and reminders|Alarm û bîranîn|ئاگادارکەرەوە و بیرخەرەوەکان|المنبهات والتذكيرات
Alarmı düzenle|Edit alarm|Alarmê biguherîne|دەستکاریکردنی ئاگادارکەرەوە|تعديل المنبه
Alarmı sil|Delete alarm|Alarmê jê bibe|سڕینەوەی ئاگادارکەرەوە|حذف المنبه
Albümler|Albums|Albûm|ئەلبومەکان|الألبومات
Ana ekran widget’ı|Home screen widget|Wîdceta ekrana sereke|ویجێتی شاشەی سەرەکی|أداة الشاشة الرئيسية
Ana ekrana basılı tutup Widget’lar bölümünden B Music’i seç.|Long-press the home screen and pick B Music under Widgets.|Li ser ekrana sereke dirêj bitikîne û ji Wîdcetan B Music hilbijêre.|لەسەر شاشەی سەرەکی پەنجە ڕابگرە و لە ویجێتەکان B Music هەڵبژێرە.|اضغط مطولاً على الشاشة الرئيسية واختر B Music من الأدوات.
Android 12+ duvar kağıdı renklerini kullan|Use Android 12+ wallpaper colors|Rengên wêneya paşxaneyê ya Android 12+ bikar bîne|ڕەنگەکانی وێنەی باکگراوندی Android 12+ بەکاربهێنە|استخدم ألوان خلفية Android 12+
Anladım|Got it|Min fêm kir|تێگەیشتم|فهمت
Anonim kullanım istatistikleri ve çökme raporları (Firebase). Uygulamayı geliştirmemize yardım eder.|Anonymous usage statistics and crash reports (Firebase). Helps us improve the app.|Statîstîkên bikaranînê yên bênav û raporên têkçûnê (Firebase). Alîkariya pêşxistina sepanê dike.|ئاماری بەکارهێنانی بێناو و ڕاپۆرتی تێکچوون (Firebase). یارمەتیمان دەدات بەرنامەکە باشتر بکەین.|إحصاءات استخدام مجهولة وتقارير أعطال (Firebase). تساعدنا على تحسين التطبيق.
Arka planda video sesi|Video audio in background|Dengê vîdyoyê li paşxaneyê|دەنگی ڤیدیۆ لە پاشبنەما|صوت الفيديو في الخلفية
Uygulamadan çıkınca müzik çalmaya devam etsin|Keep playing music after leaving the app|Dema ji sepanê derkevî muzîk berdewam bike|کاتێک لە بەرنامە دەردەچیت مۆسیقا بەردەوام بێت|استمرار الموسيقى بعد الخروج من التطبيق
Ekran kapalıyken video sesi çalmaya devam etsin|Keep video audio playing with the screen off|Dema ekran girtî be dengê vîdyoyê berdewam bike|کاتێک شاشە کوژاوەیە دەنگی ڤیدیۆ بەردەوام بێت|استمرار صوت الفيديو والشاشة مطفأة
Ekran kapalıyken ses devam eder|Audio continues with the screen off|Deng bi ekrana girtî berdewam dike|دەنگ بە شاشەی کوژاوە بەردەوام دەبێت|يستمر الصوت والشاشة مطفأة
Arka planda video duraklar|Video pauses in background|Vîdyo li paşxaneyê radiweste|ڤیدیۆ لە پاشبنەما ڕادەوەستێت|يتوقف الفيديو مؤقتاً في الخلفية
Arşivinden keşfet|Discover your library|Ji arşîva xwe keşf bike|لە ئەرشیفەکەت بدۆزەرەوە|اكتشف مكتبتك
Atla|Skip|Derbas bibe|تێپەڕاندن|تخطي
Ayarlar › Dil: Türkçe, English, Kurdî, Soranî, العربية. Tüm ekranlar seçilen dile geçer.|Settings › Language: Türkçe, English, Kurdî, Soranî, العربية. Every screen switches to the chosen language.|Mîheng › Ziman: Türkçe, English, Kurdî, Soranî, العربية. Hemû ekran bi zimanê hilbijartî dibin.|ڕێکخستنەکان › زمان: Türkçe، English، Kurdî، Soranî، العربية. هەموو شاشەکان دەگۆڕێن بۆ زمانی هەڵبژێردراو.|الإعدادات › اللغة: Türkçe، English، Kurdî، Soranî، العربية. تتحول كل الشاشات إلى اللغة المختارة.
Ayarlar › Oynatma: bugün kaç dakika dinledin, en sevdiklerin.|Settings › Playback: minutes listened today and your favorites.|Mîheng › Lêdan: îro çend deqe guhdarî kir, yên herî hezkirî.|ڕێکخستنەکان › لێدان: ئەمڕۆ چەند خولەک گوێت گرت و دڵخوازەکانت.|الإعدادات › التشغيل: دقائق الاستماع اليوم والأكثر تفضيلاً.
Ayarlar › Oynatma: kulaklıkta etrafını saran uzamsal ses.|Settings › Playback: spatial sound that surrounds you in headphones.|Mîheng › Lêdan: dengê fezayî ku di guhguhkê de dora te digire.|ڕێکخستنەکان › لێدان: دەنگی بۆشایی کە لە گوێگرەکەدا دەورت دەدات.|الإعدادات › التشغيل: صوت مكاني يحيط بك في السماعات.
Ayarları sıfırla|Reset settings|Mîhengan ji nû ve saz bike|ڕێکخستنەکان سفر بکەرەوە|إعادة ضبط الإعدادات
Açık|On|Vekirî|کراوە|مفعّل
Kapalı|Off|Girtî|داخراو|متوقف
A–B bölüm tekrarı|A–B repeat|Dubarekirina beşa A–B|دووبارەکردنەوەی بەشی A–B|تكرار المقطع A–B
Bağlantıyı aç|Open link|Girêdanê veke|کردنەوەی بەستەر|فتح الرابط
Başla|Start|Dest pê bike|دەستپێکردن|ابدأ
Başlangıç ve bitişi seç. Şarkı değişince bölüm tekrarı kapanır.|Pick start and end. Repeat turns off when the song changes.|Destpêk û dawiyê hilbijêre. Dema stran biguhere dubarekirin diqede.|سەرەتا و کۆتایی هەڵبژێرە. کە گۆرانی گۆڕا دووبارەکردنەوە دەکوژێتەوە.|اختر البداية والنهاية. يتوقف التكرار عند تغيير الأغنية.
Beğendiysen Google Play'de 5 yıldız ver ⭐|If you like it, rate 5 stars on Google Play ⭐|Ger te hez kir, li Google Play 5 stêrk bide ⭐|ئەگەر بەدڵت بوو، لە Google Play ٥ ئەستێرە بدە ⭐|إن أعجبك، قيّمه بـ 5 نجوم على Google Play ⭐
Bildirim ve kilit ekranı görünürlüğünü yönet.|Manage notification and lock screen visibility.|Xuyabûna agahdarî û ekrana kilîtkirî birêve bibe.|بەڕێوەبردنی دەرکەوتنی ئاگادارکردنەوە و شاشەی قوفڵ.|إدارة ظهور الإشعارات وشاشة القفل.
Bilinmeyen sanatçı|Unknown artist|Hunermendê nenas|هونەرمەندی نەناسراو|فنان غير معروف
Bir şarkı seç|Pick a song|Stranekê hilbijêre|گۆرانییەک هەڵبژێرە|اختر أغنية
Bitti|Done|Qediya|تەواو|تم
Boyut bilinmiyor|Size unknown|Mezinahî nenas e|قەبارە نەزانراوە|الحجم غير معروف
Bu adla bir liste var. Farklı bir ad seç.|A playlist with this name exists. Choose another name.|Lîsteyek bi vî navî heye. Navekî din hilbijêre.|لیستێک بەم ناوە هەیە. ناوێکی تر هەڵبژێرە.|توجد قائمة بهذا الاسم. اختر اسماً آخر.
Bu cihaz ekolayzeri desteklemiyor. Müzik çalmaya devam edebilirsin.|This device doesn't support the equalizer. You can keep playing music.|Ev cîhaz piştgiriya ekualayzerê nake. Tu dikarî muzîkê berdewam bikî.|ئەم ئامێرە پشتگیری یەکسانکەر ناکات. دەتوانیت مۆسیقا بەردەوام بکەیت.|هذا الجهاز لا يدعم المعادل. يمكنك متابعة تشغيل الموسيقى.
Bu dosya biçiminde bilgi yazma desteklenmiyor. MP3, M4A, MP4, FLAC, WAV ve APE düzenlenebilir.|Writing tags isn't supported for this format. MP3, M4A, MP4, FLAC, WAV and APE can be edited.|Ji bo vê formatê nivîsandina agahiyan nayê piştgirîkirin. MP3, M4A, MP4, FLAC, WAV û APE têne guhertin.|نووسینی زانیاری بۆ ئەم جۆرە پشتگیری ناکرێت. MP3، M4A، MP4، FLAC، WAV و APE دەستکاری دەکرێن.|كتابة البيانات غير مدعومة لهذا التنسيق. يمكن تعديل MP3 وM4A وMP4 وFLAC وWAV وAPE.
Bu dosya oynatılamadı. Dosya silinmiş veya desteklenmiyor olabilir.|This file couldn't be played. It may be deleted or unsupported.|Ev pel nehat lêdan. Dibe ku hatibe jêbirin an nayê piştgirîkirin.|ئەم فایلە لێنەدرا. لەوانەیە سڕابێتەوە یان پشتگیری نەکرێت.|تعذر تشغيل هذا الملف. ربما حُذف أو غير مدعوم.
Bu şarkı bitince durdur|Stop after this song|Piştî vê stranê raweste|دوای ئەم گۆرانییە ڕابگرە|إيقاف بعد هذه الأغنية
Bu şarkıyı tekrar et|Repeat this song|Vê stranê dubare bike|ئەم گۆرانییە دووبارە بکەرەوە|كرر هذه الأغنية
Bugün (dakika)|Today (minutes)|Îro (deqe)|ئەمڕۆ (خولەک)|اليوم (دقائق)
Gün serisi|Day streak|Rêza rojan|زنجیرەی ڕۆژ|أيام متتالية
Henüz dinleme kaydı yok|No listening history yet|Hêj tomara guhdariyê tune|هێشتا تۆماری گوێگرتن نییە|لا يوجد سجل استماع بعد
Daha Fazla|More|Bêtir|زیاتر|المزيد
Destek|Support|Piştgirî|پشتگیری|الدعم
Değişiklikler yeni bir müzik dosyasına yazılır. Orijinal kayıt korunur; kaydetme konumunu sen seçersin.|Changes are written to a new music file. The original is kept; you choose where to save.|Guhertin di pelê muzîkê yê nû de têne nivîsandin. Ya orîjînal tê parastin; cihê tomarkirinê tu hildibijêrî.|گۆڕانکارییەکان لە فایلێکی نوێدا دەنووسرێن. ڕەسەنەکە دەپارێزرێت؛ شوێنی پاشەکەوت خۆت هەڵدەبژێریت.|تُكتب التغييرات في ملف موسيقى جديد. يُحفظ الأصل وتختار مكان الحفظ.
Dikeyde yukarı / aşağı kaydır|Swipe up / down vertically|Bi dirêjî jor / jêr bikişîne|بە ستوونی سەرەوە / خوارەوە ڕابکێشە|اسحب للأعلى / للأسفل عمودياً
Dinleme istatistikleri|Listening stats|Statîstîkên guhdariyê|ئاماری گوێگرتن|إحصاءات الاستماع
Dosya açılamadı. Dosya erişimini kontrol edin.|Couldn't open the file. Check file access.|Pel venebû. Destûra pelan kontrol bike.|فایلەکە نەکرایەوە. دەستگەیشتن بە فایل بپشکنە.|تعذر فتح الملف. تحقق من صلاحية الوصول.
Dosya bilgilerini düzenle|Edit file info|Agahiyên pelê biguherîne|دەستکاریکردنی زانیاری فایل|تعديل معلومات الملف
Dosyalarım|My files|Pelên min|فایلەکانم|ملفاتي
Duyuru bildirimleri|Announcement notifications|Agahdariyên ragihandinê|ئاگادارکردنەوەی ڕاگەیاندن|إشعارات الإعلانات
Duyurular|Announcements|Ragihandin|ڕاگەیاندنەکان|الإعلانات
Düzenlenen müzik kaydedildi. Orijinal dosya korundu.|Edited music saved. Original file kept.|Muzîka guhertî hate tomarkirin. Pelê orîjînal hate parastin.|مۆسیقای دەستکاریکراو پاشەکەوت کرا. فایلی ڕەسەن پارێزرا.|تم حفظ الموسيقى المعدلة. تم الاحتفاظ بالأصل.
Düzenlenmiş kopyayı kaydet|Save edited copy|Kopiya guhertî tomar bike|پاشەکەوتکردنی کۆپی دەستکاریکراو|حفظ النسخة المعدلة
E-posta adresi kopyalandı|Email address copied|Navnîşana e-nameyê hate kopîkirin|ناونیشانی ئیمەیڵ کۆپی کرا|تم نسخ البريد الإلكتروني
E-posta ile gönder|Send by email|Bi e-nameyê bişîne|ناردن بە ئیمەیڵ|إرسال بالبريد
Ekolayzer için önce bir şarkı açın. Cihazın ses efektlerini desteklemesi gerekir.|Play a song first to use the equalizer. The device must support audio effects.|Ji bo ekualayzerê pêşî stranekê veke. Divê cîhaz piştgiriya bandorên deng bike.|بۆ یەکسانکەر سەرەتا گۆرانییەک بکەرەوە. ئامێرەکە دەبێت پشتگیری کاریگەری دەنگ بکات.|شغّل أغنية أولاً لاستخدام المعادل. يجب أن يدعم الجهاز المؤثرات الصوتية.
Ekran kapalıyken de videonun sesi çalmaya devam eder.|Video audio keeps playing even with the screen off.|Dengê vîdyoyê bi ekrana girtî jî berdewam dike.|دەنگی ڤیدیۆ بە شاشەی کوژاوەش بەردەوام دەبێت.|يستمر صوت الفيديو حتى مع إطفاء الشاشة.
Ekranı TV veya Chromecast’e yansıt|Mirror the screen to a TV or Chromecast|Ekranê li TV an Chromecast nîşan bide|شاشە بۆ TV یان Chromecast بنێرە|اعكس الشاشة على التلفاز أو Chromecast
En çok izlenenler|Most watched|Herî zêde temaşekirî|زۆرترین سەیرکراو|الأكثر مشاهدة
Ertele 10 dakika sonra tekrar çalar. Alarm, telefon yeniden başlasa da kurulu kalır.|Snooze rings again after 10 minutes. The alarm stays set even after a restart.|Paşxistin piştî 10 deqeyan dîsa lê dide. Alarm piştî vekirina nû jî dimîne.|دواخستن دوای ١٠ خولەک دووبارە لێدەدات. ئاگادارکەرەوە دوای دەستپێکردنەوەش دەمێنێت.|الغفوة ترن مجدداً بعد 10 دقائق. يبقى المنبه مضبوطاً حتى بعد إعادة التشغيل.
Etiket (isteğe bağlı)|Label (optional)|Etîket (bijarte)|ناونیشان (ئارەزوومەندانە)|التسمية (اختياري)
Favori|Favorite|Bijarte|دڵخواز|مفضلة
Favoriler ve çalma listelerini yedekle|Back up favorites and playlists|Bijarte û lîsteyan paşguh bike|پاشەکەوتی یەدەگی دڵخواز و لیستەکان|نسخ احتياطي للمفضلة والقوائم
Fikrini veya önerini doğrudan bize ilet|Send us your idea or suggestion directly|Raman an pêşniyara xwe rasterast ji me re bişîne|بیرۆکە یان پێشنیارەکەت ڕاستەوخۆ بۆمان بنێرە|أرسل لنا فكرتك أو اقتراحك مباشرة
Filtrele|Filter|Parzûn bike|پاڵاوتن|تصفية
Galeriye kaydetmek için depolama izni gerekiyor|Storage permission is needed to save to the gallery|Ji bo tomarkirina li galeriyê destûra depoyê pêwîst e|بۆ پاشەکەوتکردن لە گەلەری مۆڵەتی بیرگە پێویستە|يلزم إذن التخزين للحفظ في المعرض
Genel|General|Giştî|گشتی|عام
Gerekli izinleri sırayla aç|Grant the required permissions in order|Destûrên pêwîst li pey hev veke|مۆڵەتە پێویستەکان بە ڕیز بکەرەوە|امنح الأذونات المطلوبة بالترتيب
Geçiş efekti|Crossfade|Bandora derbasbûnê|کاریگەری گواستنەوە|تأثير الانتقال
Geçiş efekti (crossfade)|Crossfade|Bandora derbasbûnê (crossfade)|کاریگەری گواستنەوە (crossfade)|تأثير الانتقال (crossfade)
Görünüm|View|Dîtin|ڕووکار|العرض
Güncelleme klasörü yok|No update folder|Peldanka nûkirinê tune|بوخچەی نوێکردنەوە نییە|لا يوجد مجلد تحديث
Hareket Kontrolleri|Gesture Controls|Kontrolên Tevgerê|کۆنترۆڵی جووڵە|التحكم بالإيماءات
Hareket kontrolleri|Gesture controls|Kontrolên tevgerê|کۆنترۆڵی جووڵە|التحكم بالإيماءات
Henüz alarm yok|No alarms yet|Hêj alarm tune|هێشتا ئاگادارکەرەوە نییە|لا توجد منبهات بعد
Henüz duyuru yok|No announcements yet|Hêj ragihandin tune|هێشتا ڕاگەیاندن نییە|لا توجد إعلانات بعد
Her ruh haline bir liste.|A playlist for every mood.|Ji bo her halî lîsteyek.|لیستێک بۆ هەموو حاڵەتێک.|قائمة لكل مزاج.
Izgara|Grid|Tor|تۆڕ|شبكة
Kaldığım yeri hatırla|Remember where I left off|Cihê ku lê mam bi bîr bîne|شوێنی وەستانم لەبیر بێت|تذكر موضع التوقف
Kapak fotoğrafı seç|Choose cover photo|Wêneya bergê hilbijêre|وێنەی بەرگ هەڵبژێرە|اختر صورة الغلاف
Kapak seç|Choose cover|Berg hilbijêre|بەرگ هەڵبژێرە|اختر غلافاً
Kapat|Close|Bigire|داخستن|إغلاق
Kapağı kaldır|Remove cover|Bergê rake|لابردنی بەرگ|إزالة الغلاف
Kart görünümü|Card view|Dîtina kartê|ڕووکاری کارت|عرض البطاقات
Karışık çal|Shuffle|Tevlihev lê bide|تێکەڵ لێبدە|تشغيل عشوائي
Karışık çalmayı kapat|Turn off shuffle|Tevlihevî bigire|تێکەڵ بکوژێنەوە|إيقاف العشوائي
Kaydediliyor…|Saving…|Tê tomarkirin…|پاشەکەوت دەکرێت…|جارٍ الحفظ…
Kitaplıkta şarkı bulunamadı|No songs found in the library|Di pirtûkxaneyê de stran nehat dîtin|هیچ گۆرانییەک لە کتێبخانەدا نەدۆزرایەوە|لم يُعثر على أغانٍ في المكتبة
Klasör bulunamadı|No folders found|Peldank nehat dîtin|بوخچە نەدۆزرایەوە|لم يُعثر على مجلدات
Klasörler|Folders|Peldank|بوخچەکان|المجلدات
Klip hazırlanıyor…|Preparing clip…|Klîp tê amadekirin…|کلیپ ئامادە دەکرێت…|جارٍ تجهيز المقطع…
Komut anlaşılamadı. “Sonraki”, “Önceki”, “Dur”, “Çal” deneyin.|Command not understood. Try “Next”, “Previous”, “Stop”, “Play”.|Ferman nehat fêmkirin. “Piştî”, “Berê”, “Raweste”, “Lêxe” biceribîne.|فەرمانەکە تێنەگەیشت. “دواتر”، “پێشوو”، “ڕاگرتن”، “لێدان” تاقی بکەرەوە.|لم يُفهم الأمر. جرّب “التالي”، “السابق”، “توقف”، “تشغيل”.
Kontroller|Controls|Kontrol|کۆنترۆڵەکان|عناصر التحكم
Kopyala|Copy|Kopî bike|کۆپی|نسخ
Kullanım ve hata raporları|Usage and crash reports|Raporên bikaranîn û xeletiyê|ڕاپۆرتی بەکارهێنان و هەڵە|تقارير الاستخدام والأعطال
Liste|List|Lîste|لیست|قائمة
Liste görünümü|List view|Dîtina lîsteyê|ڕووکاری لیست|عرض القائمة
Liste sabitleme kaydedilemedi.|Couldn't save the pinned playlist.|Lîsteya derzîkirî nehat tomarkirin.|جێگیرکردنی لیست پاشەکەوت نەکرا.|تعذر حفظ تثبيت القائمة.
Listene eklemek istediğin şarkıları seç|Pick songs to add to your playlist|Stranên ku dixwazî li lîsteyê zêde bikî hilbijêre|ئەو گۆرانیانە هەڵبژێرە کە دەتەوێت زیادیان بکەیت|اختر الأغاني لإضافتها إلى قائمتك
Medya|Media|Medya|میدیا|الوسائط
Medya izinlerini yönet|Manage media permissions|Destûrên medyayê birêve bibe|بەڕێوەبردنی مۆڵەتی میدیا|إدارة أذونات الوسائط
Mini oynatıcıyı gizle|Hide mini player|Lêdera biçûk veşêre|شاردنەوەی لێدەری بچووک|إخفاء المشغل المصغر
Mini oynatıcıyı göster|Show mini player|Lêdera biçûk nîşan bide|پیشاندانی لێدەری بچووک|إظهار المشغل المصغر
Mini video penceresi|Mini video window|Pencereya vîdyoyê ya biçûk|پەنجەرەی بچووکی ڤیدیۆ|نافذة فيديو مصغرة
Mor|Purple|Mor|مۆر|بنفسجي
Müzik & Video|Music & Video|Muzîk & Vîdyo|مۆسیقا و ڤیدیۆ|موسيقى وفيديو
Müzik ara|Search music|Li muzîkê bigere|گەڕان بۆ مۆسیقا|ابحث عن موسيقى
Müzik arşivi|Music library|Arşîva muzîkê|ئەرشیفی مۆسیقا|مكتبة الموسيقى
Müzik arşivi okunamadı. İzinleri kontrol edip yeniden tara.|Couldn't read the music library. Check permissions and rescan.|Arşîva muzîkê nehat xwendin. Destûran kontrol bike û dîsa bigere.|ئەرشیفی مۆسیقا نەخوێندرایەوە. مۆڵەتەکان بپشکنە و دووبارە بگەڕێ.|تعذرت قراءة مكتبة الموسيقى. تحقق من الأذونات وأعد الفحص.
Müzik arşivinden bir şarkı açtığında oynatıcı burada hazır.|When you open a song from your library, the player is ready here.|Dema ji arşîvê stranekê vekî, lêder li vir amade ye.|کاتێک گۆرانییەک لە ئەرشیف دەکەیتەوە، لێدەر لێرە ئامادەیە.|عند فتح أغنية من مكتبتك يكون المشغل جاهزاً هنا.
Müzik ve video her zaman seninle|Music and video, always with you|Muzîk û vîdyo her dem bi te re|مۆسیقا و ڤیدیۆ هەمیشە لەگەڵتن|الموسيقى والفيديو معك دائماً
Müzik ve videoların bu cihazdan okunur. Yerel dosyaların sunucuya yüklenmez.|Your music and videos are read from this device. Local files are never uploaded.|Muzîk û vîdyoyên te ji vê cîhazê têne xwendin. Pelên herêmî nayên barkirin.|مۆسیقا و ڤیدیۆکانت لەم ئامێرە دەخوێندرێنەوە. فایلە ناوخۆییەکان بار ناکرێن.|تُقرأ موسيقاك وفيديوهاتك من هذا الجهاز. لا تُرفع الملفات المحلية.
Müzikler|Music|Muzîk|مۆسیقاکان|الموسيقى
Müziğini seç|Choose your music|Muzîka xwe hilbijêre|مۆسیقاکەت هەڵبژێرە|اختر موسيقاك
Oynatma|Playback|Lêdan|لێدان|التشغيل
Oynatma hızı|Playback speed|Leza lêdanê|خێرایی لێدان|سرعة التشغيل
Oynatma kontrolleri için isteğe bağlıdır.|Optional, for playback controls.|Ji bo kontrolên lêdanê bijarte ye.|ئارەزوومەندانەیە بۆ کۆنترۆڵی لێدان.|اختياري لعناصر التحكم بالتشغيل.
Oynatma ve görünüm ayarlarını varsayılana döndür|Restore playback and appearance defaults|Mîhengên lêdan û dîtinê vegerîne ser standard|ڕێکخستنەکانی لێدان و ڕووکار بگەڕێنەوە بۆ بنەڕەت|استعادة الإعدادات الافتراضية للتشغيل والمظهر
Oynatıcı: yazılım (geniş biçim desteği)|Player: software (wide format support)|Lêder: nermalav (piştgiriya formatên fireh)|لێدەر: نەرمەکاڵا (پشتگیری فراوان)|المشغل: برمجي (دعم واسع للتنسيقات)
Oynatıcıdaki mikrofona dokun ve “Sonraki”, “Dur”, “Çal” de.|Tap the mic in the player and say “Next”, “Stop”, “Play”.|Li ser mîkrofona lêderê bitikîne û bibêje “Piştî”, “Raweste”, “Lêxe”.|دەست لە مایکی لێدەر بدە و بڵێ “دواتر”، “ڕاگرتن”، “لێدان”.|اضغط على الميكروفون في المشغل وقل “التالي”، “توقف”، “تشغيل”.
Oynatıcıdaki paylaş düğmesi: “Şu an dinliyorum” kartını hikâyende paylaş.|Share button in the player: post a “Now listening” card to your story.|Bişkoka parvekirinê: karta “Niha guhdarî dikim” di çîroka xwe de parve bike.|دوگمەی هاوبەشکردن: کارتی “ئێستا گوێ دەگرم” لە ستۆریەکەت بڵاو بکەرەوە.|زر المشاركة في المشغل: شارك بطاقة “أستمع الآن” في قصتك.
Oynatıcıyı küçült|Minimize player|Lêderê biçûk bike|بچووککردنەوەی لێدەر|تصغير المشغل
Parlaklık|Brightness|Ronahî|ڕووناکی|السطوع
Paylaşım kartı|Share card|Karta parvekirinê|کارتی هاوبەشکردن|بطاقة المشاركة
Pil kısıtlamalarını telefon ayarlarından yönet.|Manage battery restrictions in phone settings.|Sînorên betariyê ji mîhengên telefonê birêve bibe.|سنووردارکردنی پاتری لە ڕێکخستنی مۆبایل بەڕێوەببە.|أدر قيود البطارية من إعدادات الهاتف.
Sabitlediğin listeler|Your pinned playlists|Lîsteyên te yên derzîkirî|لیستە جێگیرکراوەکانت|قوائمك المثبتة
Sanatçı adı|Artist name|Navê hunermend|ناوی هونەرمەند|اسم الفنان
Sanatçılar|Artists|Hunermend|هونەرمەندەکان|الفنانون
Sağ tarafa basılı tut|Hold the right side|Aliyê rastê bigire|لای ڕاست ڕابگرە|اضغط مطولاً على الجانب الأيمن
Senin Medya Dünyan|Your Media World|Cîhana Te ya Medyayê|جیهانی میدیای تۆ|عالمك الإعلامي
Senin listelerin|Your playlists|Lîsteyên te|لیستەکانت|قوائمك
Ses|Sound|Deng|دەنگ|الصوت
Sesli komut|Voice command|Fermana dengî|فەرمانی دەنگی|أمر صوتي
8D ses|8D audio|Dengê 8D|دەنگی 8D|صوت 8D
Kulaklıkta etrafını saran uzamsal ses|Spatial sound around you in headphones|Dengê fezayî di guhguhkê de|دەنگی بۆشایی لە گوێگردا|صوت مكاني محيط في السماعات
Önce bir şarkı çal; cihaz desteklemiyorsa etkisiz kalır.|Play a song first; no effect if the device doesn't support it.|Pêşî stranekê lê bide; ger cîhaz piştgirî neke bandor nake.|سەرەتا گۆرانییەک لێبدە؛ ئەگەر ئامێر پشتگیری نەکات کار ناکات.|شغّل أغنية أولاً؛ لا تأثير إن لم يدعمه الجهاز.
Sevdiğin bir şarkıyla uyanmak için alarm ekle.|Add an alarm to wake up to a song you love.|Alarmekê zêde bike da ku bi strana hezkirî şiyar bibî.|ئاگادارکەرەوەیەک زیاد بکە بۆ هەستان بە گۆرانی دڵخوازت.|أضف منبهاً لتستيقظ على أغنية تحبها.
Son dinlenenler|Recently played|Dawî guhdarîkirî|دوایین گوێگیراوەکان|المستمع إليها مؤخراً
Son eklenen|Recently added|Dawî zêdekirî|دوایین زیادکراو|المضافة مؤخراً
Son izlenenler|Recently watched|Dawî temaşekirî|دوایین سەیرکراوەکان|شوهدت مؤخراً
Son İzlenenler|Recently Watched|Dawî Temaşekirî|دوایین سەیرکراوەکان|شوهدت مؤخراً
Sonra|Later|Paşê|دواتر|لاحقاً
Sonraki video|Next video|Vîdyoya din|ڤیدیۆی دواتر|الفيديو التالي
Sonraki şarkı|Next song|Strana din|گۆرانی دواتر|الأغنية التالية
Sonraki şarkı olarak eklendi.|Added as next song.|Wek strana din hate zêdekirin.|وەک گۆرانی دواتر زیادکرا.|أضيفت كأغنية تالية.
Sorun bildir|Report a problem|Pirsgirêkê ragihîne|ڕاپۆرتی کێشە|الإبلاغ عن مشكلة
Süre|Duration|Dem|ماوە|المدة
Süre bitmeden son 30 saniyede ses yavaşça kısılır.|In the last 30 seconds the volume fades out gently.|Di 30 çirkeyên dawî de deng hêdî hêdî kêm dibe.|لە ٣٠ چرکەی کۆتاییدا دەنگ هێواش کەم دەبێتەوە.|في آخر 30 ثانية يخفت الصوت تدريجياً.
Sıralama|Sort|Rêzkirin|ڕیزکردن|الترتيب
Sırayı listeye kaydet|Save queue as playlist|Rêzê wek lîste tomar bike|ڕیزەکە وەک لیست پاشەکەوت بکە|حفظ قائمة الانتظار كقائمة
TV'ye yansıt|Cast to TV|Li TV nîşan bide|ناردن بۆ TV|البث إلى التلفاز
Tam ekran bildirimleri|Full-screen notifications|Agahdariyên tevahiya ekranê|ئاگادارکردنەوەی پڕ شاشە|إشعارات ملء الشاشة
Tam metni aç (web)|Open full text (web)|Nivîsa tevahî veke (web)|کردنەوەی دەقی تەواو (وێب)|فتح النص الكامل (ويب)
Tek dokunuşla göster / gizle|Show / hide with one tap|Bi yek tikandinê nîşan bide / veşêre|بە یەک دەستلێدان پیشان بدە / بشارەوە|إظهار / إخفاء بنقرة واحدة
Tekrar kapalı|Repeat off|Dubare girtî|دووبارەکردنەوە کوژاوە|التكرار متوقف
Tekrarla|Repeat|Dubare bike|دووبارەکردنەوە|تكرار
Tema, renkler, uygulama simgesi ve ana sayfa|Theme, colors, app icon and home page|Tema, reng, îkona sepanê û rûpela sereke|ڕووپۆش، ڕەنگ، ئایکۆن و پەڕەی سەرەکی|السمة والألوان والأيقونة والصفحة الرئيسية
Temizle|Clear|Paqij bike|پاککردنەوە|مسح
Teşekkürler! Önerin bize ulaştı.|Thanks! Your suggestion reached us.|Spas! Pêşniyara te gihişt me.|سوپاس! پێشنیارەکەت گەیشت.|شكراً! وصلنا اقتراحك.
Tüm sırayı tekrar et|Repeat whole queue|Hemû rêzê dubare bike|هەموو ڕیزەکە دووبارە بکەرەوە|تكرار القائمة كلها
Tüm şarkılar|All songs|Hemû stran|هەموو گۆرانییەکان|كل الأغاني
Tümünü çal|Play all|Hemûyan lê bide|هەمووی لێبدە|تشغيل الكل
Uygula|Apply|Bicîh bîne|جێبەجێکردن|تطبيق
Uygulama Simgesi|App Icon|Îkona Sepanê|ئایکۆنی بەرنامە|أيقونة التطبيق
Uygulama tanıtımı|App tour|Naskirina sepanê|ناساندنی بەرنامە|جولة في التطبيق
Uygulamayı paylaş|Share the app|Sepanê parve bike|هاوبەشکردنی بەرنامە|مشاركة التطبيق
Uygulamayı puanla|Rate the app|Sepanê binirxîne|هەڵسەنگاندنی بەرنامە|قيّم التطبيق
Uyku zamanlayıcısı|Sleep timer|Demjimêra xewê|کاتژمێری خەوتن|مؤقت النوم
Varsayılan alarm sesi|Default alarm sound|Dengê alarmê yê standard|دەنگی بنەڕەتی ئاگادارکەرەوە|صوت المنبه الافتراضي
Veriler|Data|Dane|داتا|البيانات
Video bilgileri|Video info|Agahiyên vîdyoyê|زانیاری ڤیدیۆ|معلومات الفيديو
Video geçmişi kaydedilemedi.|Couldn't save video history.|Dîroka vîdyoyê nehat tomarkirin.|مێژووی ڤیدیۆ پاشەکەوت نەکرا.|تعذر حفظ سجل الفيديو.
Video menüsünden (⋮) telefon ekranını TV veya Chromecast’e yansıt.|From the video menu (⋮) mirror your screen to a TV or Chromecast.|Ji menuya vîdyoyê (⋮) ekranê li TV an Chromecast nîşan bide.|لە لیستی ڤیدیۆ (⋮) شاشەکەت بۆ TV یان Chromecast بنێرە.|من قائمة الفيديو (⋮) اعكس شاشتك على التلفاز أو Chromecast.
Video oynarken ana ekran tuşuna bas: video küçük pencerede sürer.|Press Home while a video plays: it continues in a small window.|Dema vîdyo dilîze bişkoka sereke bitikîne: vîdyo di pencereya biçûk de berdewam dike.|کاتێک ڤیدیۆ لێدەدرێت دوگمەی سەرەکی دابگرە: لە پەنجەرەی بچووکدا بەردەوام دەبێت.|اضغط زر الرئيسية أثناء الفيديو: يستمر في نافذة صغيرة.
Video silinsin mi?|Delete video?|Vîdyo were jêbirin?|ڤیدیۆکە بسڕدرێتەوە؟|حذف الفيديو؟
Video yatayken: sağ ses, sol parlaklık, yatay sarma|In landscape video: right volume, left brightness, horizontal seek|Di vîdyoya berfireh de: rast deng, çep ronahî, bi berfirehî bazdan|لە ڤیدیۆی ئاسۆیی: ڕاست دەنگ، چەپ ڕووناکی، ئاسۆیی گواستنەوە|في الوضع الأفقي: اليمين للصوت، اليسار للسطوع، أفقياً للتقديم
Videolar|Videos|Vîdyo|ڤیدیۆکان|الفيديوهات
Videolara dön|Back to videos|Vegere vîdyoyan|گەڕانەوە بۆ ڤیدیۆکان|العودة إلى الفيديوهات
Videolarda ara|Search videos|Li vîdyoyan bigere|گەڕان لە ڤیدیۆکان|ابحث في الفيديوهات
Videoları listelemek ve oynatmak için gereklidir.|Required to list and play videos.|Ji bo lîstekirin û lêdana vîdyoyan pêwîst e.|بۆ لیستکردن و لێدانی ڤیدیۆ پێویستە.|مطلوب لعرض الفيديوهات وتشغيلها.
Videoya çift dokun|Double-tap the video|Du caran li vîdyoyê bitikîne|دوو جار دەست لە ڤیدیۆ بدە|انقر مرتين على الفيديو
Videoyu kes|Trim video|Vîdyoyê bibire|بڕینی ڤیدیۆ|قص الفيديو
Yakınlaştır|Zoom|Nêzîk bike|نزیککردنەوە|تكبير
Yansıtma bu cihazda açılamadı|Couldn't start casting on this device|Nîşandan li ser vê cîhazê venebû|ناردن لەم ئامێرەدا نەکرایەوە|تعذر بدء البث على هذا الجهاز
Yasal|Legal|Qanûnî|یاسایی|قانوني
Yatayda sağ tarafta yukarı / aşağı|Landscape: up / down on the right|Berfireh: li rastê jor / jêr|ئاسۆیی: سەرەوە / خوارەوە لە لای ڕاست|أفقياً: أعلى / أسفل على اليمين
Yatayda sağa veya sola kaydır|Landscape: swipe left or right|Berfireh: ber bi rast an çep bikişîne|ئاسۆیی: بۆ ڕاست یان چەپ ڕابکێشە|أفقياً: اسحب يميناً أو يساراً
Yatayda sol tarafta yukarı / aşağı|Landscape: up / down on the left|Berfireh: li çepê jor / jêr|ئاسۆیی: سەرەوە / خوارەوە لە لای چەپ|أفقياً: أعلى / أسفل على اليسار
Yeni|New|Nû|نوێ|جديد
Yeni alarm|New alarm|Alarma nû|ئاگادارکەرەوەی نوێ|منبه جديد
Yeni liste oluştur|Create new playlist|Lîsteya nû çêke|دروستکردنی لیستی نوێ|إنشاء قائمة جديدة
Yeni sürüm var|New version available|Guhertoya nû heye|وەشانی نوێ هەیە|يتوفر إصدار جديد
Yenile|Refresh|Nû bike|نوێکردنەوە|تحديث
Yenilikler|What's new|Nûbûn|نوێکارییەکان|الجديد
Yerel medya arşivi|Local media library|Arşîva medyaya herêmî|ئەرشیفی میدیای ناوخۆیی|مكتبة الوسائط المحلية
Zamanlayıcıyı iptal et|Cancel timer|Demjimêrê betal bike|هەڵوەشاندنەوەی کاتژمێر|إلغاء المؤقت
Çalan müzik ve kilit ekranı medya kontrolleri|Now-playing and lock screen media controls|Muzîka dilîze û kontrolên medyayê yên ekrana kilîtkirî|مۆسیقای لێدراو و کۆنترۆڵی شاشەی قوفڵ|عناصر التحكم في الموسيقى وشاشة القفل
Çalma listesine ekle|Add to playlist|Li lîsteyê zêde bike|زیادکردن بۆ لیست|إضافة إلى قائمة التشغيل
Çalma sırası|Queue|Rêza lêdanê|ڕیزی لێدان|قائمة الانتظار
Çalma sırasına eklendi.|Added to queue.|Li rêzê hate zêdekirin.|زیادکرا بۆ ڕیز.|أضيفت إلى قائمة الانتظار.
Önceki şarkı|Previous song|Strana berê|گۆرانی پێشوو|الأغنية السابقة
Öneri Kutusu|Suggestion Box|Qutiya Pêşniyaran|سندوقی پێشنیار|صندوق الاقتراحات
Önizle|Preview|Pêşdîtin|پێشبینین|معاينة
Örneğin: İşe git|E.g.: Go to work|Mînak: Here kar|بۆ نموونە: بڕۆ بۆ کار|مثال: الذهاب إلى العمل
İki parmağınla büyüt / küçült|Pinch to zoom in / out|Bi du tiliyan mezin / biçûk bike|بە دوو پەنجە گەورە / بچووک بکە|كبّر / صغّر بإصبعين
İleri / geri sar|Seek forward / back|Pêş / paş bibe|پێشەوە / دواوە|تقديم / ترجيع
İndirme bağlantısını arkadaşlarına gönder|Send the download link to friends|Girêdana daxistinê ji hevalan re bişîne|بەستەری داگرتن بۆ هاوڕێکانت بنێرە|أرسل رابط التنزيل لأصدقائك
İptal|Cancel|Betal|هەڵوەشاندنەوە|إلغاء
İzin işlemi tamamlanamadı. Telefon ayarlarını kontrol edin.|Permission request failed. Check phone settings.|Destûr temam nebû. Mîhengên telefonê kontrol bike.|مۆڵەت تەواو نەبوو. ڕێکخستنی مۆبایل بپشکنە.|تعذر إكمال الإذن. تحقق من إعدادات الهاتف.
İzinleri daha sonra Ayarlar bölümünden de değiştirebilirsin.|You can change permissions later in Settings.|Tu dikarî destûran paşê ji Mîhengan biguherînî.|دەتوانیت دواتر مۆڵەتەکان لە ڕێکخستنەکان بگۆڕیت.|يمكنك تغيير الأذونات لاحقاً من الإعدادات.
İzlediğin videolar burada görünecek.|Videos you watch will appear here.|Vîdyoyên ku temaşe dikî dê li vir xuya bibin.|ئەو ڤیدیۆیانەی سەیری دەکەیت لێرە دەردەکەون.|ستظهر هنا الفيديوهات التي تشاهدها.
İşlem tamamlanamadı. Dosya ve erişim izinlerini kontrol et.|Couldn't complete. Check file and access permissions.|Kar temam nebû. Destûrên pel û gihîştinê kontrol bike.|کارەکە تەواو نەبوو. مۆڵەتی فایل و دەستگەیشتن بپشکنە.|تعذر الإكمال. تحقق من أذونات الملف والوصول.
İşlem tamamlanamadı. Tekrar deneyin.|Couldn't complete. Please try again.|Kar temam nebû. Dîsa biceribîne.|کارەکە تەواو نەبوو. دووبارە هەوڵ بدەرەوە.|تعذر الإكمال. حاول مرة أخرى.
Şarkı adı|Song title|Navê stranê|ناوی گۆرانی|اسم الأغنية
Şarkı ara|Search songs|Li stranê bigere|گەڕان بۆ گۆرانی|ابحث عن أغنية
Şarkı seçenekleri|Song options|Vebijarkên stranê|هەڵبژاردەکانی گۆرانی|خيارات الأغنية
Şarkı ve videolar kaldığı yerden başlasın|Resume songs and videos where they stopped|Stran û vîdyo ji cihê mayî dest pê bikin|گۆرانی و ڤیدیۆ لە شوێنی وەستان دەستپێبکەن|استئناف الأغاني والفيديو من حيث توقفت
Şarkılar|Songs|Stran|گۆرانییەکان|الأغاني
Şarkılar birbirine yumuşakça geçsin (crossfade).|Songs blend smoothly into each other (crossfade).|Stran bi nermî derbasî hev bibin (crossfade).|گۆرانییەکان بە نەرمی بگوازرێنەوە (crossfade).|انتقال سلس بين الأغاني (crossfade).
Şarkıları listelemek ve çalmak için gereklidir.|Required to list and play songs.|Ji bo lîstekirin û lêdana stranan pêwîst e.|بۆ لیستکردن و لێدانی گۆرانی پێویستە.|مطلوب لعرض الأغاني وتشغيلها.
Şu an B Music’te dinliyorum|Now listening on B Music|Niha li B Music guhdarî dikim|ئێستا لە B Music گوێ دەگرم|أستمع الآن على B Music
Şu an dinliyorum|Now listening|Niha guhdarî dikim|ئێستا گوێ دەگرم|أستمع الآن
Yeni özellikler var! Kısa ipuçlarına göz at.|New features! Take a look at the quick tips.|Taybetmendiyên nû hene! Li şîretên kurt binêre.|تایبەتمەندی نوێ هەیە! سەیری ئامۆژگارییە کورتەکان بکە.|ميزات جديدة! ألقِ نظرة على النصائح السريعة.
ŞİMDİ ÇALIYOR|NOW PLAYING|NIHA TÊ LÊDAN|ئێستا لێدەدرێت|يُشغّل الآن
Videolar ekranı ve video oynatıcıdaki TV düğmesinden Chromecast / TV yansıt.|Use the TV button on the Videos screen and video player for Chromecast / TV cast.|Ji bişkoka TV ya ekrana Vîdyoyan û lêdera vîdyoyê Chromecast / TV nîşan bide.|لە دوگمەی TVی شاشەی ڤیدیۆ و لێدەری ڤیدیۆ Chromecast / TV بنێرە.|استخدم زر التلفاز في شاشة الفيديوهات ومشغل الفيديو للبث إلى Chromecast / التلفاز.
Senin için|For you|Ji bo te|بۆ تۆ|لك
Önerilenler|Recommended|Pêşniyarkirî|پێشنیارکراو|موصى به
{0} video · Cihaz arşivi|{0} videos · Device library|{0} vîdyo · Arşîva amûrê|{0} ڤیدیۆ · ئەرشیفی ئامێر|{0} فيديو · مكتبة الجهاز
{0} video|{0} videos|{0} vîdyo|{0} ڤیدیۆ|{0} فيديو
{0} şarkı|{0} songs|{0} stran|{0} گۆرانی|{0} أغنية
{0} dakika|{0} minutes|{0} deqe|{0} خولەک|{0} دقيقة
Videolarda ara...|Search videos...|Li vîdyoyan bigere...|گەڕان لە ڤیدیۆکان...|ابحث في الفيديوهات...
Şarkılarda ara|Search songs|Li stranan bigere|گەڕان بۆ گۆرانی|ابحث عن أغنية
Sınırlı erişim • Video seçimini değiştir|Limited access • Change video selection|Gihîştina sînorkirî • Hilbijartina vîdyoyê biguherîne|دەستگەیشتنی سنووردار • هەڵبژاردنی ڤیدیۆ بگۆڕە|وصول محدود • غيّر اختيار الفيديو
OYNATMA|PLAYBACK|LÊDAN|لێدان|التشغيل
DÜZENLE|EDIT|BIGUHERÎNE|دەستکاری|تعديل
DOSYA|FILE|PEL|فایل|ملف
Oynatma hızı|Playback speed|Leza lêdanê|خێرایی لێدان|سرعة التشغيل
Tekrar oynat|Loop|Dubare lê bide|دووبارە لێدان|تكرار التشغيل
Ekranı doldur|Fill screen|Ekranê tijî bike|شاشە پڕ بکە|ملء الشاشة
Yatay / dikey döndür|Rotate landscape / portrait|Berfireh / dirêj bizivirîne|ئاسۆیی / ستوونی بسوڕێنە|تدوير أفقي / عمودي
Ekran kilidi|Screen lock|Kilîta ekranê|قفڵی شاشە|قفل الشاشة
Sesi aç/kapat|Mute / unmute|Dengê veke/bigire|دەنگ بکەرەوە/بکوژێنەوە|كتم / إلغاء الكتم
Yakınlaştırmayı sıfırla|Reset zoom|Nêzîkbûnê sifir bike|نزیککردنەوە سفر بکەرەوە|إعادة تعيين التكبير
Kırp|Trim|Bibire|بڕین|قص
Ekran görüntüsü|Screenshot|Wêneyê ekranê|وێنەی شاشە|لقطة شاشة
Ses olarak dinle|Listen as audio|Wek deng guhdarî bike|وەک دەنگ گوێ بگرە|استمع كصوت
Sayfayı kapat|Close sheet|Rûpelê bigire|پەڕە دابخە|إغلاق الصفحة
Dil, görünüm, başlangıç ekranı|Language, appearance, start screen|Ziman, dîtin, ekrana destpêkê|زمان، ڕووکار، شاشەی دەستپێک|اللغة والمظهر وشاشة البداية
Dil tercihi kaydedilir. Çevirisi bulunmayan metinler Türkçe gösterilir.|Language preference is saved. Untranslated text stays in Turkish.|Tercîha zimanê tê tomarkirin. Nivîsên bê werger bi Tirkî dimînin.|هەڵبژاردەی زمان پاشەکەوت دەکرێت. دەقی بێ وەرگێڕان بە تورکی دەمێنێت.|يُحفظ تفضيل اللغة. يبقى النص غير المترجم بالتركية.
Kalite ve kod çözücü|Quality and decoder|Kalîte û kodker|کوالیتی و دیکۆدەر|الجودة ووحدة فك الترميز
Yedeği dışa aktar|Export backup|Paşguh derxe|هەناردەی یەدەگ|تصدير النسخة الاحتياطية
Yedeği içe aktar|Import backup|Paşguh têxe|هاوردەی یەدەگ|استيراد النسخة الاحتياطية
Alarm|Alarm|Alarm|ئاگادارکەرەوە|منبه
Klasörlere dön|Back to folders|Vegere peldankan|گەڕانەوە بۆ بوخچەکان|العودة إلى المجلدات
Gruplara dön|Back to groups|Vegere koman|گەڕانەوە بۆ گرووپەکان|العودة إلى المجموعات
Video açılamadı. Dosyayı ve izinleri kontrol edin.|Couldn't open the video. Check the file and permissions.|Vîdyo venebû. Pel û destûran kontrol bike.|ڤیدیۆ نەکرایەوە. فایل و مۆڵەت بپشکنە.|تعذر فتح الفيديو. تحقق من الملف والأذونات.
15 sn ses seç|Pick 15s of audio|15 çirke deng hilbijêre|١٥ چرکە دەنگ هەڵبژێرە|اختر ١٥ ثانية من الصوت
Paylaşım kartı + 15 sn ses|Share card + 15s audio|Karta parvekirinê + 15 çirke deng|کارتی هاوبەشکردن + ١٥ چرکە دەنگ|بطاقة مشاركة + ١٥ ثانية صوت
Videoyu paylaş|Share video|Vîdyoyê parve bike|هاوبەشکردنی ڤیدیۆ|مشاركة الفيديو
Ses klibi hazırlanıyor…|Preparing audio clip…|Klîba deng tê amadekirin…|کلیپی دەنگ ئامادە دەکرێت…|جارٍ تجهيز مقطع الصوت…
15 saniyelik sesi kaydırarak seç|Slide to pick the 15-second audio|Bi kişandinê dengê 15 çirkeyî hilbijêre|بە ڕاکێشان ١٥ چرکە دەنگ هەڵبژێرە|اسحب لاختيار ١٥ ثانية من الصوت
Başlangıç|Start|Destpêk|سەرەتا|البداية
Kart + ses paylaşıldı|Card + audio shared|Kart + deng hate parvekirin|کارت + دەنگ هاوبەش کرا|تمت مشاركة البطاقة والصوت
Ses klibi çıkarılamadı|Couldn't extract the audio clip|Klîba deng derneket|کلیپی دەنگ دەرهێنەنەکرا|تعذر استخراج مقطع الصوت
TV yansıtma|Cast to TV|Nîşandana TV|ناردن بۆ TV|البث إلى التلفاز
Devam: {0}|Resume: {0}|Berdewam: {0}|بەردەوام: {0}|متابعة: {0}
Bildirim ve kilit ekranı görünürlüğünü Android ayarları belirler.|Android settings control notification and lock screen visibility.|Xuyabûna agahdarî û ekrana kilîtkirî Android mîheng dike.|دەرکەوتنی ئاگادارکردنەوە و شاشەی قوفڵ Android ڕێکدەخات.|تحدد إعدادات Android ظهور الإشعارات وشاشة القفل.
Listeye şarkı ekle|Add songs to playlist|Stranan li lîsteyê zêde bike|گۆرانی زیاد بکە بۆ لیست|أضف أغانٍ إلى القائمة
Yeni çalma listesi|New playlist|Lîsteya lêdanê ya nû|لیستی لێدانی نوێ|قائمة تشغيل جديدة
Yeni liste adı|New playlist name|Navê lîsteya nû|ناوی لیستی نوێ|اسم القائمة الجديدة
Sıradan kaldır|Remove from queue|Ji rêzê rake|لە ڕیز لایببە|إزالة من قائمة الانتظار
Tüm listeyi çal|Play entire list|Hemû lîsteyê lê bide|هەموو لیستەکە لێبدە|تشغيل القائمة كلها
Müzikleri yeniden tara|Rescan music|Muzîkan dîsa bigere|دووبارە گەڕان بۆ مۆسیقا|إعادة فحص الموسيقى
Aramayı temizle|Clear search|Lêgerînê paqij bike|گەڕان پاک بکەرەوە|مسح البحث
Daha fazla seçenek|More options|Vebijarkên zêdetir|هەڵبژاردەی زیاتر|المزيد من الخيارات
''';

/// Translates a UI string into the selected language (TR fallback).
String tr(String text) =>
    translate(text, PlayerPreferences.instance.text('language', 'tr'));
