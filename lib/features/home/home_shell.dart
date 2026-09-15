import 'package:flutter/material.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import 'global_mini_player.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onRequestLogin, required this.onSignOut});
  final Future<void> Function() onRequestLogin;
  final Future<void> Function() onSignOut;
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _homeRevision = 0;
  void _select(int i) { if (i == _index) return; setState(() { _index=i; if(i==0)_homeRevision++; }); }
  List<Widget> _screens()=>[
    MusicHomeScreen(key:ValueKey(_homeRevision),onOpenMusic:()=>_select(1),onOpenDiscover:()=>_select(1),onRequestLogin:widget.onRequestLogin),
    const LibraryScreen(), const LocalVideoScreen(), const _PlaylistsHub(), const _SettingsHub(),
  ];
  static const items=[
    _DockItem(Icons.home_rounded,'Ana Sayfa'),_DockItem(Icons.music_note_rounded,'Müzik'),_DockItem(Icons.smart_display_rounded,'Video'),_DockItem(Icons.playlist_play_rounded,'Listeler'),_DockItem(Icons.settings_rounded,'Ayarlar')];
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:AppColors.background,extendBody:true,body:IndexedStack(index:_index,children:_screens()),bottomNavigationBar:SafeArea(top:false,child:Column(mainAxisSize:MainAxisSize.min,children:[Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:GlobalMiniPlayer(onOpenMusic:()=>_select(1))),Container(height:68,decoration:const BoxDecoration(color:Color(0xFF090A12),border:Border(top:BorderSide(color:Color(0xFF242637)))),child:Row(children:List.generate(items.length,(i)=>Expanded(child:_DockButton(item:items[i],selected:i==_index,onTap:()=>_select(i))))))])));
}

class _PlaylistsHub extends StatefulWidget { const _PlaylistsHub(); @override State<_PlaylistsHub> createState()=>_PlaylistsHubState(); }
class _PlaylistsHubState extends State<_PlaylistsHub>{
 final music=LocalMusicService.instance;
 Future<void> add() async {final x=TextEditingController();final name=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Yeni Liste'),content:TextField(controller:x,autofocus:true,decoration:const InputDecoration(hintText:'Liste adı')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,x.text.trim()),child:const Text('Oluştur'))]));x.dispose();if(name!=null&&name.isNotEmpty){await music.createPlaylist(name);if(mounted)setState((){});}}
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Listelerim'),actions:[Padding(padding:const EdgeInsets.only(right:12),child:FilledButton.icon(onPressed:add,icon:const Icon(Icons.add,size:18),label:const Text('Yeni Liste')))]),body:ListView(padding:const EdgeInsets.fromLTRB(16,10,16,130),children:[Row(children:[Expanded(child:_Stat(Icons.favorite_rounded,'Favoriler','${music.favoriteSongs.length} şarkı')),const SizedBox(width:10),const Expanded(child:_Stat(Icons.history_rounded,'Son Dinlenenler','Geçmiş')),const SizedBox(width:10),const Expanded(child:_Stat(Icons.bar_chart_rounded,'En Çok','Dinlenenler'))]),const SizedBox(height:24),const Text('Çalma Listelerim',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:10),if(music.playlists.isEmpty)const _EmptyList() else ...music.playlists.entries.map((e)=>_PlaylistTile(name:e.key,count:e.value.length))]));
}
class _Stat extends StatelessWidget{const _Stat(this.icon,this.title,this.sub);final IconData icon;final String title,sub;@override Widget build(BuildContext c)=>Container(height:112,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(17),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:AppColors.neonPink,size:27),const Spacer(),Text(title,maxLines:1,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),Text(sub,maxLines:1,style:const TextStyle(color:AppColors.textSecondary,fontSize:10))]));}
class _PlaylistTile extends StatelessWidget{const _PlaylistTile({required this.name,required this.count});final String name;final int count;@override Widget build(BuildContext c)=>ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),leading:Container(width:52,height:52,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFF4BB8),Color(0xFF6C2BFF)]),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.queue_music_rounded)),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('$count şarkı'),trailing:const Icon(Icons.more_vert_rounded));}
class _EmptyList extends StatelessWidget{const _EmptyList();@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(18)),child:const Column(children:[Icon(Icons.playlist_add_rounded,size:40,color:AppColors.neonPurple),SizedBox(height:8),Text('İlk çalma listeni oluştur',style:TextStyle(fontWeight:FontWeight.w800)),Text('Şarkılarını kendi listelerinde düzenle',style:TextStyle(color:AppColors.textSecondary,fontSize:12))]));}

class _SettingsHub extends StatelessWidget{const _SettingsHub();@override Widget build(BuildContext c)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(title:const Text('Ayarlar')),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,130),children:[const _Setting(Icons.palette_rounded,'Görünüm ve Tema','Koyu / Açık tema, renk seçenekleri'),const _Setting(Icons.volume_up_rounded,'Ses Ayarları','Ses kalitesi ve oynatma ayarları'),const _Setting(Icons.graphic_eq_rounded,'Ekolayzer','Müziğini istediğin gibi ayarla'),const _Setting(Icons.timer_rounded,'Uyku Zamanlayıcısı','Belirli sürede otomatik durdur'),const _Setting(Icons.video_library_rounded,'Medya Tarama','Cihazdaki müzik ve videoları tara'),const _Setting(Icons.notifications_active_rounded,'Bildirim ve Kilit Ekranı Kontrolleri','Oynatma kontrollerini yönet'),const _Setting(Icons.language_rounded,'Dil','Türkçe (Türkiye)'),const _Setting(Icons.tune_rounded,'Gelişmiş Ayarlar','Ek seçenekler'),const _Setting(Icons.info_outline_rounded,'Uygulama Hakkında','B_music02 yerel medya oynatıcı'),const SizedBox(height:14),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.border)),child:const Row(children:[Icon(Icons.lock_rounded,color:AppColors.textSecondary),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Müzik ve videolar cihazınızda kalır.',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:3),Text('Kişisel medya dosyalarınız sunucuya yüklenmez.',style:TextStyle(color:AppColors.textSecondary,fontSize:11))]))]))]));}
class _Setting extends StatelessWidget{const _Setting(this.icon,this.title,this.sub);final IconData icon;final String title,sub;@override Widget build(BuildContext c)=>Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.border)),child:ListTile(leading:Container(width:38,height:38,decoration:BoxDecoration(color:AppColors.surfaceAlt,borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:AppColors.neonPurple,size:21)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),subtitle:Text(sub,style:const TextStyle(color:AppColors.textSecondary,fontSize:10)),trailing:const Icon(Icons.chevron_right_rounded,size:20)));}
class _DockButton extends StatelessWidget{const _DockButton({required this.item,required this.selected,required this.onTap});final _DockItem item;final bool selected;final VoidCallback onTap;@override Widget build(BuildContext c){final col=selected?AppColors.neonPink:const Color(0xFF8C8E9F);return InkWell(onTap:onTap,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(item.icon,color:col,size:22),const SizedBox(height:3),Text(item.label,maxLines:1,style:TextStyle(color:col,fontSize:8.5,fontWeight:selected?FontWeight.w800:FontWeight.w500))]));}}
class _DockItem{const _DockItem(this.icon,this.label);final IconData icon;final String label;}
