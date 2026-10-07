import 'dart:math' as math;
import 'package:flutter/material.dart';

const brandPurple = Color(0xFF9F28FF);
const brandGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
  colors: [Color(0xFFCE72FF), Color(0xFF8D16F8), Color(0xFF6512E8)]);
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset('assets/images/b_music02_logo.png', width: size, height: size, fit: BoxFit.contain, semanticLabel: 'B Music');
}
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onTap, this.icon = Icons.arrow_forward_rounded});
  final String label; final VoidCallback? onTap; final IconData icon;
  @override
  Widget build(BuildContext c) => DecoratedBox(decoration: BoxDecoration(gradient: brandGradient,
    borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFD291FF)),
    boxShadow: const [BoxShadow(color: Color(0x664C00D4), blurRadius: 18)]),
    child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(28),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 10), Icon(icon, color: Colors.white, size: 20)])))));
}
class NightLandscape extends StatelessWidget {
  const NightLandscape({super.key, this.child, this.hero = false});
  final Widget? child; final bool hero;
  @override
  Widget build(BuildContext c) => CustomPaint(painter: _Landscape(hero), child: child);
}
class _Landscape extends CustomPainter {
  _Landscape(this.hero); final bool hero;
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,
      colors: [Color(0xFF07051A),Color(0xFF251046),Color(0xFF090615)]).createShader(rect));
    c.drawRect(rect, Paint()..shader = RadialGradient(center: Alignment(hero ? .45 : .05, -.25),radius: .8,
      colors: const [Color(0x997E27D8), Color(0x003C1268)]).createShader(rect));
    final rng = math.Random(34);
    for (var i=0;i<160;i++) { final x=rng.nextDouble()*s.width,y=rng.nextDouble()*s.height*.67;
      c.drawCircle(Offset(x,y), rng.nextDouble()*.9+.2, Paint()..color=Colors.white.withValues(alpha:rng.nextDouble()*.7+.15)); }
    for(var layer=0;layer<3;layer++) {
      final path=Path()..moveTo(0,s.height);
      final heights = layer==0 ? [.65,.49,.58,.34,.51,.4,.65,.47,.55] : layer==1 ? [.77,.62,.72,.52,.74,.57,.74,.61,.77] : [.85,.76,.87,.7,.85,.8,.9,.74,.86];
      for(var i=0;i<heights.length;i++) {path.lineTo(s.width*i/(heights.length-1),s.height*heights[i]);}
      path..lineTo(s.width,s.height)..close();
      c.drawPath(path,Paint()..color=[const Color(0xFF5B2B88),const Color(0xFF27153F),const Color(0xFF0A0A16)][layer]);
      if(layer==0) {
        final snow=Path()..moveTo(s.width*.375,s.height*.34)..lineTo(s.width*.32,s.height*.44)..lineTo(s.width*.38,s.height*.4)..lineTo(s.width*.43,s.height*.44)..close();
        c.drawPath(snow,Paint()..color=const Color(0xFFCE9AD8));
      }
    }
    for(var i=0;i<22;i++) { final x = (i/21)*s.width; final h=s.height*(.07+rng.nextDouble()*.12);final y=s.height*(.85+rng.nextDouble()*.12);
      final p=Path()..moveTo(x,y-h)..lineTo(x-h*.35,y)..lineTo(x+h*.35,y)..close();c.drawPath(p,Paint()..color=const Color(0xFF04070C)); }
  }
  @override bool shouldRepaint(covariant _Landscape old) => old.hero!=hero;
}
class GestureGuideScreen extends StatelessWidget {
  const GestureGuideScreen({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Hareket Kontrolleri')),body: GridView.count(
    padding: const EdgeInsets.all(16),crossAxisCount: MediaQuery.sizeOf(c).width>600?3:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.92,
    children: [for(final item in const <(IconData,String,String)>[
      (Icons.brightness_6_outlined,'Parlaklık','Yatayda sol tarafta yukarı / aşağı'),(Icons.volume_up_outlined,'Ses','Yatayda sağ tarafta yukarı / aşağı'),
      (Icons.swipe_right_alt,'İleri / geri sar','Yatayda sağa veya sola kaydır'),(Icons.swipe_vertical_outlined,'Sonraki video','Dikeyde yukarı / aşağı kaydır'),
      (Icons.favorite_border,'Favori','Videoya çift dokun'),(Icons.touch_app_outlined,'Kontroller','Tek dokunuşla göster / gizle'),
      (Icons.speed,'2× hız','Sağ tarafa basılı tut'),(Icons.pinch_outlined,'Yakınlaştır','İki parmağınla büyüt / küçült')])
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color: const Color(0xFF101017),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF64358C))),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(item.$1,color:const Color(0xFFCC88FF),size:36),const SizedBox(height:18),Text(item.$2,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),Text(item.$3,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60,fontSize:12))]))]));
}
