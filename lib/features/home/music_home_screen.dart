import '../../core/l10n/app_text.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_catalog.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/search_history.dart';
import '../../core/services/thumbnail_cache.dart';
import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import '../../core/services/contact_service.dart';
import '../../core/theme/aurora.dart';
import '../profile/feedback_screen.dart';
import '../profile/player_settings_screen.dart';
import 'full_player_screen.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'song_collection_screen.dart';
import 'widgets/music_widgets.dart';
import 'widgets/reference_design.dart';
import 'widgets/search_history_panel.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key,required this.onOpenMusic,this.onOpenVideo,this.music});
  final VoidCallback onOpenMusic; final VoidCallback? onOpenVideo; final LocalMusicService? music;
  @override State<MusicHomeScreen> createState()=>_HomeState();
}
class _HomeState extends State<MusicHomeScreen> {
  late final music=widget.music??LocalMusicService.instance;
  final videos=VideoLibrary.instance;
  final videoPrefs=VideoPreferences.instance;
  final prefs=PlayerPreferences.instance;
  List<SongModel> recent=[], top=[], forgotten=[], fresh=[];
  final search = TextEditingController();
  final searchFocus = FocusNode();
  bool showHistory = false;
  StreamSubscription<void>? changes;
  @override void initState(){super.initState();music.addListener(changed);videos.addListener(changed);videoPrefs.addListener(changed);prefs.addListener(changed);
    changes=MusicInsightsService.instance.changes.listen((_)=>history());
    searchFocus.addListener(() { if (mounted) setState(() => showHistory = searchFocus.hasFocus && search.text.isEmpty); });
    unawaited(load());}
  @override void dispose(){music.removeListener(changed);videos.removeListener(changed);videoPrefs.removeListener(changed);prefs.removeListener(changed);changes?.cancel();search.dispose();searchFocus.dispose();super.dispose();}
  void changed(){if(mounted)setState((){});}
  Future<void> load() async {await music.requestPermissionAndLoad(request:false);await history();if(widget.music==null)await videos.scan();}
  Future<void> history() async {
    final insights = MusicInsightsService.instance;
    final values = await Future.wait([
      insights.recentTracks(limit:30),
      insights.topTracks(limit:40),
      insights.forgottenTracks(limit:40),
    ]);
    final byId={for(final s in music.songs)s.id.toString():s};
    SongModel? map(TrackInsight e) => byId[e.id];
    if(mounted)setState((){
      recent=values[0].map(map).whereType<SongModel>().toList();
      top=values[1].map(map).whereType<SongModel>().toList();
      forgotten=values[2].map(map).whereType<SongModel>().toList();
      fresh=selectMusic(music.songs,sort:MusicSort.newest);
      if (forgotten.isEmpty) {
        final recentIds = {for (final s in recent) s.id};
        forgotten = music.songs.where((s) => !recentIds.contains(s.id)).take(40).toList();
      }
    });
  }
  void collection(String title,List<SongModel> songs)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>SongCollectionScreen(title:title,songs:songs,music:music)));
  void archive({String folder='Tümü',bool recent=false,bool fresh=false,bool mostWatched=false})=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LocalVideoScreen(initialFolder:folder,initialRecent:recent,initialNew:fresh,initialMostWatched:mostWatched)));
  void favorites()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LibraryScreen(music:music,favoritesOnly:true)));
  void openSearch({String? query, int? tab})=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LibraryScreen(music:music,focusSearch:true,initialQuery:query,initialTab:tab)));
  Future<void> submitSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) { openSearch(); return; }
    await SearchHistory.instance.add(q);
    if (mounted) openSearch(query: q);
  }
  Future<void> shuffle()async {if(music.songs.isEmpty){widget.onOpenMusic();return;}await music.player.setShuffleModeEnabled(true);await music.playSong(music.songs[Random().nextInt(music.songs.length)],from:music.songs);}
  Widget section(String title,VoidCallback tap)=>AuroraSectionHeader(title:title,action:tap);

  SongModel? get continueSong {
    return music.currentSong ?? (recent.isNotEmpty ? recent.first : (fresh.isNotEmpty ? fresh.first : null));
  }

  @override Widget build(BuildContext c){
    final tracks=recent.isEmpty?fresh:recent;
    final byId={for(final v in videos.videos)v.asset.id:v};
    final watched=videoPrefs.recent.map((id)=>byId[id]).whereType<LocalVideo>().take(10).toList();
    final artists = groupMusic(music.songs, MusicGroup.artist);
    final artistEntries = artists.entries.take(10).toList();
    final scheme = Theme.of(c).colorScheme;
    final continuing = continueSong;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom:false,child:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,10,16,150),children:[Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          AppText(Aurora.greeting(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.1, height: 1.05)),
          const SizedBox(height: 4),
          AppText(Aurora.greetingSubtitle(), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ])),
        IconButton(
          tooltip: 'Karışık çal',
          onPressed: () => runMusicAction(c, shuffle),
          icon: const Icon(Icons.shuffle_rounded),
        ),
        const BrandLogo(size: 36),
        HomeMenuButton(onSettings:()=>Navigator.push(c,MaterialPageRoute<void>(builder:(_)=>const PlayerSettingsScreen()))),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: search,
        focusNode: searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() => showHistory = searchFocus.hasFocus && search.text.isEmpty),
        onSubmitted: submitSearch,
        decoration: InputDecoration(
          hintText: tr('Sanatçı, şarkı veya video ara'),
          prefixIcon: IconButton(tooltip: 'Müzik ara', onPressed: () => submitSearch(search.text), icon: const Icon(Icons.search)),
          suffixIcon: search.text.isEmpty ? null : IconButton(
            tooltip: tr('Aramayı temizle'),
            onPressed: () { search.clear(); setState(() {}); },
            icon: const Icon(Icons.close_rounded),
          ),
          filled: true,
          fillColor: auroraSurface(c),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Aurora.glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Aurora.electric, width: 1.3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
      SearchHistoryPanel(
        visible: showHistory,
        onSelect: (q) { search.text = q; unawaited(submitSearch(q)); },
      ),
      const SizedBox(height: 16),
      if (continuing != null)
        _ContinueCard(song: continuing, music: music, onOpen: () => openFullPlayer(c, music: music)),
      if (artistEntries.isNotEmpty) ...[
        AuroraSectionHeader(title: 'Sanatçıların', action: () => openSearch(tab: 3), actionLabel: 'Daha fazla'),
        SizedBox(height: 96, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: artistEntries.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (c, i) {
            if (i == artistEntries.length) {
              return InkWell(
                onTap: () => openSearch(tab: 3),
                child: Column(children: [
                  CircleAvatar(radius: 32, backgroundColor: Aurora.glassFillStrong, child: const Icon(Icons.add, color: Colors.white)),
                  const SizedBox(height: 6),
                  const AppText('Daha fazla', style: TextStyle(fontSize: 11)),
                ]),
              );
            }
            final entry = artistEntries[i];
            final name = entry.key.split('\u0000').first;
            return InkWell(
              onTap: () => collection(name, entry.value),
              child: SizedBox(width: 72, child: Column(children: [
                MediaArtwork(id: entry.value.first.id, size: 64, radius: 32),
                const SizedBox(height: 6),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ])),
            );
          },
        )),
      ],
      AuroraSectionHeader(title: "Senin için mix'ler", action: widget.onOpenMusic),
      SizedBox(height: 118, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final mixes = <(IconData, List<Color>, String, String, List<SongModel>, String)>[
            (Icons.favorite_rounded, [const Color(0xFF8B5CFF), const Color(0xFF5A2BFF)], 'Favorilerim', tf('{0} şarkı', [music.favoriteSongs.length]), music.favoriteSongs, 'Favorilerim'),
            (Icons.graphic_eq_rounded, [const Color(0xFFFF8A6B), const Color(0xFFFF5A4A)], 'En çok dinlenen', tf('{0} şarkı', [top.length]), top, 'En çok dinlenenler'),
            (Icons.schedule_rounded, [const Color(0xFF4C8DFF), const Color(0xFF2A5BFF)], 'Son eklenen', tf('{0} şarkı', [fresh.length]), fresh, 'Yeni eklenenler'),
            (Icons.auto_awesome, [const Color(0xFFC84CFF), const Color(0xFF7A28E8)], 'Uzun zamandır dinlemediklerin', tf('{0} şarkı', [forgotten.length]), forgotten, 'Uzun zamandır dinlemediklerin'),
          ];
          final m = mixes[i];
          return SizedBox(width: 128, child: _MixCard(icon: m.$1, colors: m.$2, title: m.$3, subtitle: m.$4, onTap: () {
            if (m.$5.isEmpty) { if (i==0) favorites(); else widget.onOpenMusic(); return; }
            collection(m.$6, m.$5);
          }));
        },
      )),
      section('Hızlı Erişim',widget.onOpenMusic),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[for(final item in <(IconData,String,VoidCallback)>[
        (Icons.smart_display_outlined,'Tüm\nVideolar',widget.onOpenVideo??()=>archive()),(Icons.library_music_outlined,'Tüm\nMüzikler',widget.onOpenMusic),
        (Icons.update,'Son\nEklenenler',()=>collection('Yeni eklenenler',fresh)),(Icons.trending_up_rounded,'En Çok\nİzlenenler',()=>archive(mostWatched:true))])
        Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:_Shortcut(label:item.$2,icon:item.$1,color:const Color(0xFFB14CFF),onTap:item.$3)))]),
      if(prefs.flag('homeRecent',fallback:true))...[section('Son İzlenenler',()=>archive(recent:true)),
      if(watched.isEmpty) GlassCard(child:Row(children:[const Icon(Icons.history,color:Color(0xFFBB62FF)),const SizedBox(width:12),const Expanded(child:AppText('İzlediğin videolar burada görünecek.',style:TextStyle(fontSize:12))),IconButton(onPressed:widget.onOpenVideo??()=>archive(),icon:const Icon(Icons.chevron_right))]))
      else SizedBox(height:91,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:watched.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i)=>SizedBox(width:130,child:_RecentVideo(video:watched[i],playlist:watched))))],
      if(music.pinnedPlaylistNames.isNotEmpty)...[section('Sabitlediğin listeler',widget.onOpenMusic),for(final name in music.pinnedPlaylistNames) ListTile(leading:const Icon(Icons.folder_special,color:Color(0xFFBE6AFF)),title:AppText(name),trailing:const Icon(Icons.chevron_right),onTap:()=>collection(name,music.playlistSongs(name)))],
      if(tracks.isNotEmpty)...[section(recent.isEmpty?'Arşivinden keşfet':'Son Dinlenenler',()=>collection('Son dinlenenler',tracks)),for(final s in tracks.take(4))MusicSongTile(song:s,music:music,onPlay:()=>music.playSong(s,from:tracks))],
      ], // Column children
      ), // Column
      ], // ListView children
      ), // ListView
      ), // RefreshIndicator
      ), // SafeArea
    ); // Scaffold
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.song, required this.music, required this.onOpen});
  final SongModel song;
  final LocalMusicService music;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final current = music.currentSong?.id == song.id;
    return StreamBuilder<Duration>(
      stream: music.player.positionStream,
      builder: (c, snap) {
        final pos = current ? (snap.data ?? music.player.position) : Duration.zero;
        final durMs = (current ? (music.player.duration?.inMilliseconds ?? song.duration ?? 1) : (song.duration ?? 1)).clamp(1, 1 << 30);
        final progress = (pos.inMilliseconds / durMs).clamp(0.0, 1.0);
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          glow: true,
          onTap: onOpen,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppText('Kaldığın yerden devam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const AppText('Sonraki parçaya geç', style: TextStyle(fontSize: 12, color: Aurora.textMuted)),
            const SizedBox(height: 10),
            Row(children: [
              MediaArtwork(id: song.id, size: 48, radius: 10),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(songArtist(song), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Aurora.textMuted)),
              ])),
              const SizedBox(width: 8),
              SizedBox(width: 72, height: 72, child: Stack(alignment: Alignment.center, children: [
                MediaArtwork(id: song.id, size: 72, radius: 14),
                Material(
                  color: Aurora.electricDeep.withValues(alpha: .85),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => runMusicAction(c, () async {
                      if (current) {
                        await music.togglePlayPause();
                      } else {
                        await music.playSong(song, from: music.songs);
                      }
                    }),
                    child: const SizedBox(width: 44, height: 44, child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32)),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              AppText(formatMusicTime(pos), style: const TextStyle(fontSize: 10, color: Aurora.textMuted)),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: progress, minHeight: 4,
                backgroundColor: Colors.white12, color: Aurora.electric,
              ))),
              const SizedBox(width: 8),
              AppText(formatMusicTime(Duration(milliseconds: durMs == 1 << 30 ? 0 : durMs)), style: const TextStyle(fontSize: 10, color: Aurora.textMuted)),
            ]),
          ]),
        );
      },
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.icon, required this.colors, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final List<Color> colors; final String title, subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Colors.white, size: 26),
            const Spacer(),
            AppText(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, height: 1.15)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        ),
      ),
    ),
  );
}

class _Shortcut extends StatelessWidget {
 const _Shortcut({required this.label,required this.icon,required this.color,required this.onTap});final String label;final IconData icon;final Color color;final VoidCallback onTap;
 @override Widget build(BuildContext c)=>Material(color:Theme.of(c).colorScheme.surface,borderRadius:BorderRadius.circular(12),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:12),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:26)),const SizedBox(height:9),AppText(label,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,height:1.3))]))));
}
class _RecentVideo extends StatefulWidget {
 const _RecentVideo({required this.video,this.playlist});final LocalVideo video;final List<LocalVideo>? playlist;
 @override State<_RecentVideo> createState()=>_RecentVideoState();
}
class _RecentVideoState extends State<_RecentVideo>{
 late final Future<Uint8List?> thumb=ThumbnailCache.instance.get(widget.video.asset,width:480,height:270);
 @override Widget build(BuildContext c)=>InkWell(onTap:()=>openLocalVideo(c,widget.video,playlist:widget.playlist),child:ClipRRect(borderRadius:BorderRadius.circular(10),child:Stack(fit:StackFit.expand,children:[Builder(builder:(c){final warm=ThumbnailCache.instance.memoryHit(widget.video.asset,width:480,height:270);if(warm!=null)return Image.memory(warm,fit:BoxFit.cover,gaplessPlayback:true,cacheWidth:300);return FutureBuilder<Uint8List?>(future:thumb,builder:(c,s)=>s.data==null?const ColoredBox(color:Color(0xFF1D1728),child:Icon(Icons.play_circle_outline)):Image.memory(s.data!,fit:BoxFit.cover,gaplessPlayback:true,cacheWidth:300));}),Positioned(right:5,bottom:5,child:Container(padding:const EdgeInsets.all(3),color:const Color(0xB3000000),child:AppText('${widget.video.asset.duration~/60}:${(widget.video.asset.duration%60).toString().padLeft(2,'0')}',style:const TextStyle(color:Colors.white,fontSize:10))))])));
}

/// Home header ⋮: İletişim, Öneri Kutusu, Uygulamayı paylaş, Ayarlar.
class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({super.key, required this.onSettings});
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext c) => PopupMenuButton<String>(
        tooltip: tr('Daha fazla seçenek'),
        icon: const Icon(Icons.more_vert_rounded),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (value) {
          switch (value) {
            case 'contact':
              contactUs(c);
            case 'feedback':
              Navigator.push(c, MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()));
            case 'share':
              ContactService.shareApp();
            case 'settings':
              onSettings();
          }
        },
        itemBuilder: (_) => [
          for (final item in const <(String, IconData, String)>[
            ('contact', Icons.mail_outline_rounded, 'İletişim'),
            ('feedback', Icons.lightbulb_outline_rounded, 'Öneri Kutusu'),
            ('share', Icons.share_outlined, 'Uygulamayı paylaş'),
            ('settings', Icons.settings_outlined, 'Ayarlar'),
          ])
            PopupMenuItem<String>(
              value: item.$1,
              child: Row(children: [
                Icon(item.$2, size: 21, color: const Color(0xFFC07BFF)),
                const SizedBox(width: 14),
                Flexible(child: AppText(item.$3, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
      );
}
