import '../../../core/l10n/app_text.dart';
import 'vinyl_record.dart';
import 'package:flutter/material.dart';

const brandPurple = Color(0xFFFF9A3C);
const brandGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
  colors: [Color(0xFFF6B778), Color(0xFFFF9A3C), Color(0xFFBC631F)]);
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(label: 'B Music',
    child: Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(size * .32)),
      child: ExcludeSemantics(child: Text('B', style: TextStyle(fontFamily: 'Fraunces',
        height: 1, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold,
        fontSize: size * .64, color: Theme.of(context).colorScheme.onPrimary)))));
}
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onTap, this.icon = Icons.arrow_forward_rounded});
  final String label; final VoidCallback? onTap; final IconData icon;
  @override
  Widget build(BuildContext c) => DecoratedBox(decoration: BoxDecoration(gradient: brandGradient,
    borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFF6B778)),
    boxShadow: const [BoxShadow(color: Color(0x221A100A), blurRadius: 18)]),
    child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(28),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        AppText(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 10), Icon(icon, color: Colors.white, size: 20)])))));
}
class RecordBackdrop extends StatelessWidget {
  const RecordBackdrop({super.key, this.child});
  final Widget? child;
  @override
  Widget build(BuildContext context) => ColoredBox(color: const Color(0xff14100d),
    child: Stack(fit: StackFit.expand, children: [
      const Positioned(right: -120, top: -120, child: Opacity(opacity: .34,
        child: VinylRecord(size: 380, cream: true))),
      if (child != null) child!,
    ]));
}

class GestureGuideScreen extends StatelessWidget {
  const GestureGuideScreen({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const AppText('Hareket Kontrolleri')),body: GridView.count(
    padding: const EdgeInsets.all(16),crossAxisCount: MediaQuery.sizeOf(c).width>600?3:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.92,
    children: [for(final item in const <(IconData,String,String)>[
      (Icons.brightness_6_outlined,'Parlaklık','Yatayda sol tarafta yukarı / aşağı'),(Icons.volume_up_outlined,'Ses','Yatayda sağ tarafta yukarı / aşağı'),
      (Icons.swipe_right_alt,'İleri / geri sar','Yatayda sağa veya sola kaydır'),(Icons.swipe_vertical_outlined,'Sonraki video','Dikeyde yukarı / aşağı kaydır'),
      (Icons.favorite_border,'Favori','Videoya çift dokun'),(Icons.touch_app_outlined,'Kontroller','Tek dokunuşla göster / gizle'),
      (Icons.speed,'2× hız','Sağ tarafa basılı tut'),(Icons.pinch_outlined,'Yakınlaştır','İki parmağınla büyüt / küçült')])
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color: const Color(0xFF101017),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFBC631F))),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(item.$1,color:const Color(0xFFF6B778),size:36),const SizedBox(height:18),AppText(item.$2,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),AppText(item.$3,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60,fontSize:12))]))]));
}
