import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import '../profile/player_settings_screen.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'song_collection_screen.dart';
import 'widgets/music_widgets.dart';
import 'widgets/reference_design.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key,required this.onOpenMusic,this.onOpenVideo,this.music});
  final VoidCallback onOpenMusic; final VoidCallback? onOpenVideo; final LocalMusicService? music;
  @override State<MusicHomeScreen> createState()=>_HomeState();
}
class _HomeState extends State<MusicHomeScreen> {
  late final music=widget.music??LocalMusicService.instance;
  final videos=VideoLibrary.instance;
  final videoPrefs=VideoPreferences.instance;
  List<SongModel> recent=[],top=[];
  StreamSubscription<void>? changes;
  @override void initState(){super.initState();music.addListener(changed);videos.addListener(changed);videoPrefs.addListener(changed);
    changes=MusicInsightsService.instance.changes.listen((_)=>history());unawaited(load());}
  @override void dispose(){music.removeListener(changed);videos.removeListener(changed);videoPrefs.removeListener(changed);changes?.cancel();super.dispose();}
  void changed(){if(mounted)setState((){});}
  Future<void> load() async {await music.requestPermissionAndLoad(request:false);await history();if(widget.music==null)await videos.scan();}
  Future<void> history() async {final values=await Future.wait([MusicInsightsService.instance.recentTracks(limit:30),MusicInsightsService.instance.topTracks(limit:30)]);
    final byId={for(final s in music.songs)s.id.toString():s};if(mounted)setState((){recent=values[0].map((e)=>byId[e.id]).whereType<SongModel>().toList();top=values[1].map((e)=>byId[e.id]).whereType<SongModel>().toList();});}
  void collection(String title,List<SongModel> songs)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>SongCollectionScreen(title:title,songs:songs,music:music)));
  void archive({String folder='Tümü',bool recent=false,bool fresh=false})=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalVideoScreen(initialFolder:folder,initialRecent:recent,initialNew:fresh)));
  void favorites()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LibraryScreen(music:music,favoritesOnly:true)));
  void search()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LibraryScreen(music:music,focusSearch:true)));
  Future<void> shuffle()async {if(music.songs.isEmpty){widget.onOpenMusic();return;}await music.player.setShuffleModeEnabled(true);await music.playSong(music.songs[Random().nextInt(music.songs.length)],from:music.songs);}
  Widget section(String title,VoidCallback tap)=>Padding(padding:const EdgeInsets.only(top:18,bottom:10),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700))),InkWell(onTap:tap,child:const Padding(padding:EdgeInsets.all(6),child:Icon(Icons.chevron_right,size:20)))]));
  @override Widget build(BuildContext c){
    final fresh=selectMusic(music.songs,sort:MusicSort.newest);
    final tracks=recent.isEmpty?fresh:recent;
    final byId={for(final v in videos.videos)v.asset.id:v};
    final watched=videoPrefs.recent.map((id)=>byId[id]).whereType<LocalVideo>().take(10).toList();
    final folders=videoPrefs.pinnedFolders.where(videos.folders.contains).toList();
    return Scaffold(body:SafeArea(bottom:false,child:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,10,16,150),children:[
      Row(children:[const BrandLogo(size:36),const SizedBox(width:8),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('B Music',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),Text('Müzik & Video',style:TextStyle(fontSize:11,color:Colors.white60))])),
        IconButton(constraints: const BoxConstraints.tightFor(width:36,height:44),padding:EdgeInsets.zero,tooltip:'Müzik ara',onPressed:search,icon:const Icon(Icons.search)),
        IconButton(constraints:const BoxConstraints.tightFor(width:36,height:44),padding:EdgeInsets.zero,tooltip:'Son eklenenler',onPressed:()=>archive(fresh:true),icon:const Icon(Icons.notifications_none)),
        IconButton(constraints:const BoxConstraints.tightFor(width:36,height:44),padding:EdgeInsets.zero,tooltip:'Ayarlar',onPressed:()=>Navigator.push(c,MaterialPageRoute<void>(builder:(_)=>const PlayerSettingsScreen())),icon:const Icon(Icons.settings_outlined))]),
      const SizedBox(height:14),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        ChoiceChip(showCheckmark:false,label:const Text('Tümü'),selected:true,onSelected:(_){}),const SizedBox(width:8),
        ActionChip(label:const Text('Müzik'),onPressed:widget.onOpenMusic),const SizedBox(width:8),ActionChip(label:const Text('Video'),onPressed:widget.onOpenVideo??()=>archive()),const SizedBox(width:8),ActionChip(label:const Text('Favoriler'),onPressed:favorites)])),
      const SizedBox(height:14),ClipRRect(borderRadius:BorderRadius.circular(16),child:NightLandscape(hero:true,child:Material(color:Colors.transparent,child:InkWell(onTap:()=>runMusicAction(c,shuffle),child:Padding(padding:const EdgeInsets.symmetric(horizontal:18,vertical:25),child:Row(children:[const Expanded(child:Text('Senin için\nÖnerilenler',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:Colors.white,shadows:[Shadow(color:Colors.black,blurRadius:8)]))),IconButton.filled(tooltip:'Karışık çal',onPressed:()=>runMusicAction(c,shuffle),style:IconButton.styleFrom(backgroundColor:Colors.black54,foregroundColor:Colors.white),icon:const Icon(Icons.play_arrow_rounded))])))))),
      section('Son İzlenenler',()=>archive(recent:true)),
      if(watched.isEmpty) Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Theme.of(c).colorScheme.surface,borderRadius:BorderRadius.circular(12)),child:Row(children:[const Icon(Icons.history,color:Color(0xFFBB62FF)),const SizedBox(width:12),const Expanded(child:Text('İzlediğin videolar burada görünecek.',style:TextStyle(fontSize:12))),IconButton(onPressed:widget.onOpenVideo??()=>archive(),icon:const Icon(Icons.chevron_right))]))
      else SizedBox(height:91,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:watched.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i)=>SizedBox(width:130,child:_RecentVideo(video:watched[i])))),
      section('Favori Klasörler',()=>archive()),
      if(folders.isEmpty) ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.folder_outlined,color:Color(0xFFCF71FF)),title:const Text('Klasörlerini sabitle',style:TextStyle(fontSize:13)),subtitle:const Text('Video filtrelerinden klasörlerini ana sayfaya sabitle',style:TextStyle(fontSize:11)),onTap:widget.onOpenVideo??()=>archive())
      else SizedBox(height:104,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:folders.length,separatorBuilder:(_,__)=>const SizedBox(width:9),itemBuilder:(c,i)=>SizedBox(width:78,child:_Shortcut(label:folders[i],icon:Icons.folder_rounded,color:const [Color(0xFFE569FF),Color(0xFF44ABFF),Color(0xFFFFC65E),Color(0xFF7568FF)][i%4],onTap:()=>archive(folder:folders[i]))))),
      section('Hızlı Erişim',widget.onOpenMusic),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[for(final item in <(IconData,String,VoidCallback)>[
        (Icons.smart_display_outlined,'Tüm\nVideolar',widget.onOpenVideo??()=>archive()),(Icons.library_music_outlined,'Tüm\nMüzikler',widget.onOpenMusic),
        (Icons.update,'Son\nEklenenler',()=>collection('Yeni eklenenler',fresh)),(Icons.graphic_eq,'En Çok\nDinlenenler',()=>collection('En çok dinlenenler',top))])
        Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:_Shortcut(label:item.$2,icon:item.$1,color:const Color(0xFFB14CFF),onTap:item.$3)))]),
      if(music.pinnedPlaylistNames.isNotEmpty)...[section('Sabitlediğin listeler',widget.onOpenMusic),for(final name in music.pinnedPlaylistNames) ListTile(leading:const Icon(Icons.folder_special,color:Color(0xFFBE6AFF)),title:Text(name),trailing:const Icon(Icons.chevron_right),onTap:()=>collection(name,music.playlistSongs(name)))],
      if(tracks.isNotEmpty)...[section(recent.isEmpty?'Arşivinden keşfet':'Son Dinlenenler',()=>collection('Son dinlenenler',tracks)),for(final s in tracks.take(4))MusicSongTile(song:s,music:music,onPlay:()=>music.playSong(s,from:tracks))],
    ]))));
  }
}
class _Shortcut extends StatelessWidget {
 const _Shortcut({required this.label,required this.icon,required this.color,required this.onTap});final String label;final IconData icon;final Color color;final VoidCallback onTap;
 @override Widget build(BuildContext c)=>Material(color:Theme.of(c).colorScheme.surface,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:12),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:26)),const SizedBox(height:9),Text(label,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,height:1.3))]))));
}
class _RecentVideo extends StatefulWidget {
 const _RecentVideo({required this.video});final LocalVideo video;
 @override State<_RecentVideo> createState()=>_RecentVideoState();
}
class _RecentVideoState extends State<_RecentVideo>{
 late final Future<Uint8List?> thumb=widget.video.asset.thumbnailDataWithSize(const ThumbnailSize(300,180));
 @override Widget build(BuildContext c)=>InkWell(onTap:()=>openLocalVideo(c,widget.video),child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Stack(fit:StackFit.expand,children:[FutureBuilder<Uint8List?>(future:thumb,builder:(c,s)=>s.data==null?const ColoredBox(color:Color(0xFF1D1728),child:Icon(Icons.play_circle_outline)):Image.memory(s.data!,fit:BoxFit.cover)),Positioned(right:5,bottom:5,child:Container(padding:const EdgeInsets.all(3),color:Colors.black70,child:Text('${widget.video.asset.duration~/60}:${(widget.video.asset.duration%60).toString().padLeft(2,'0')}',style:const TextStyle(color:Colors.white,fontSize:10))))])));
}
