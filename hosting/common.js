// Shared helpers for the B Music web pages (song letters, QR playlists).
const PLAY = 'https://play.google.com/store/apps/details?id=com.bmusic.app';
const LANG = (() => {
  const l = (navigator.language || 'tr').toLowerCase();
  if (l.startsWith('ckb')) return 'ckb';
  if (l.startsWith('ku') || l.startsWith('kmr')) return 'ku';
  if (l.startsWith('ar')) return 'ar';
  if (l.startsWith('tr')) return 'tr';
  return 'en';
})();
const T = {
  letterKicker: ['Sana bir şarkı mektubu geldi', 'You got a song letter', 'Nameyeke stranê ji te re hat', 'نامەیەکی گۆرانیت بۆ هات', 'وصلتك رسالة أغنية'],
  from: ['Gönderen', 'From', 'Şandiyar', 'نێرەر', 'المرسل'],
  listen: ['B Music’te dinle', 'Listen in B Music', 'Di B Music de guhdarî bike', 'لە B Music گوێ بگرە', 'استمع في B Music'],
  download: ['Uygulamayı indir', 'Download the app', 'Sepanê daxe', 'ئەپەکە دابەزێنە', 'حمّل التطبيق'],
  clip: ['Mektup klibi', 'Letter clip', 'klîba nameyê', 'کلیپی نامە', 'مقطع الرسالة'],
  fine: ['Linki açan kişi şarkıyı dinler ve istersen uygulamayı indirir.', 'Whoever opens the link can listen and download the app if they like.', 'Yê ku girêdanê veke dikare guhdarî bike û sepanê daxe.', 'هەر کەسێک لینکەکە بکاتەوە دەتوانێت گوێ بگرێت و ئەپەکە دابەزێنێت.', 'من يفتح الرابط يمكنه الاستماع وتحميل التطبيق.'],
  missing: ['Mektup bulunamadı veya silinmiş.', 'Letter not found or deleted.', 'Name nehat dîtin.', 'نامەکە نەدۆزرایەوە.', 'لم يتم العثور على الرسالة.'],
  loading: ['Mektup açılıyor…', 'Opening the letter…', 'Name vedibe…', 'نامەکە دەکرێتەوە…', 'جارٍ فتح الرسالة…'],
  listKicker: ['Seninle bir çalma listesi paylaşıldı', 'A playlist was shared with you', 'Lîsteyek bi te re hat parvekirin', 'لیستێک لەگەڵت هاوبەش کرا', 'تمت مشاركة قائمة تشغيل معك'],
  openList: ['B Music’te aç', 'Open in B Music', 'Di B Music de veke', 'لە B Music بیکەرەوە', 'افتح في B Music'],
  songs: ['şarkı', 'songs', 'stran', 'گۆرانی', 'أغانٍ'],
  listFine: ['Liste, telefonundaki aynı şarkılarla B Music’te oluşturulur.', 'B Music builds the list from the same songs on your phone.', 'B Music lîsteyê bi heman stranên li telefona te çêdike.', 'B Music لیستەکە لە هەمان گۆرانییەکانی مۆبایلەکەت دروست دەکات.', 'ينشئ B Music القائمة من نفس الأغاني على هاتفك.'],
  badList: ['Liste okunamadı.', 'Could not read the playlist.', 'Lîste nehat xwendin.', 'لیستەکە نەخوێندرایەوە.', 'تعذرت قراءة القائمة.'],
};
const IDX = { tr: 0, en: 1, ku: 2, ckb: 3, ar: 4 }[LANG];
const t = (k) => T[k][IDX];
if (LANG === 'ar' || LANG === 'ckb') document.documentElement.dir = 'rtl';
document.documentElement.lang = LANG;
const isAndroid = /android/i.test(navigator.userAgent);
function appLink(path) {
  // Opens B Music when installed, otherwise the Play Store.
  if (!isAndroid) return PLAY;
  return 'intent://' + path + '#Intent;scheme=bmusic;package=com.bmusic.app;S.browser_fallback_url=' + encodeURIComponent(PLAY) + ';end';
}
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
