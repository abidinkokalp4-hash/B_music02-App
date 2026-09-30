import 'package:on_audio_query/on_audio_query.dart';

enum MusicSort { title, artist, newest, duration }

enum MusicGroup { artist, album, folder }

const musicSortLabels = ['Şarkı adı', 'Sanatçı adı', 'Son eklenen', 'Süre'];

String knownMetadata(String? value, String fallback) {
  final text = value?.trim() ?? '';
  return text.isEmpty || text == '<unknown>' ? fallback : text;
}

String songArtist(SongModel song) =>
    knownMetadata(song.artist, 'Bilinmeyen sanatçı');

String songAlbum(SongModel song) =>
    knownMetadata(song.album, 'Bilinmeyen albüm');

// Turkish dotted/dotless I and accents should not hide matching device files.
String normalizeMusicSearch(String text) {
  const replacements = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  var normalized = text;
  replacements.forEach((key, value) {
    normalized = normalized.replaceAll(key, value);
  });
  return normalized.toLowerCase().trim();
}

List<SongModel> selectMusic(
  Iterable<SongModel> source, {
  String query = '',
  MusicSort sort = MusicSort.title,
}) {
  final words = normalizeMusicSearch(query)
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final songs = source.where((song) {
    final haystack = normalizeMusicSearch(
      '${song.title} ${songArtist(song)} ${songAlbum(song)} ${song.data}',
    );
    return words.every(haystack.contains);
  }).toList();
  songs.sort((a, b) {
    final result = switch (sort) {
      MusicSort.title =>
        normalizeMusicSearch(a.title).compareTo(normalizeMusicSearch(b.title)),
      MusicSort.artist => normalizeMusicSearch(songArtist(a))
          .compareTo(normalizeMusicSearch(songArtist(b))),
      MusicSort.newest => (b.dateAdded ?? b.dateModified ?? 0)
          .compareTo(a.dateAdded ?? a.dateModified ?? 0),
      MusicSort.duration => (b.duration ?? 0).compareTo(a.duration ?? 0),
    };
    if (result != 0) return result;
    final title =
        normalizeMusicSearch(a.title).compareTo(normalizeMusicSearch(b.title));
    return title != 0 ? title : a.id.compareTo(b.id);
  });
  return songs;
}

String songFolder(SongModel song) {
  final slash = song.data.lastIndexOf('/');
  return slash > 0 ? song.data.substring(0, slash) : 'Diğer';
}

String folderLabel(String path) => path.split('/').last;

Map<String, List<SongModel>> groupMusic(
  Iterable<SongModel> songs,
  MusicGroup group,
) {
  final result = <String, List<SongModel>>{};
  for (final song in songs) {
    final key = switch (group) {
      MusicGroup.artist => songArtist(song),
      // Identically named albums from different artists stay separate.
      MusicGroup.album => '${songAlbum(song)}\u0000${songArtist(song)}',
      MusicGroup.folder => songFolder(song),
    };
    result.putIfAbsent(key, () => []).add(song);
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String formatMusicTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 864000);
  final minutes = seconds ~/ 60;
  final tail = (seconds % 60).toString().padLeft(2, '0');
  return minutes < 60
      ? '$minutes:$tail'
      : '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$tail';
}

String musicDurationLabel(Iterable<SongModel> songs) {
  final minutes =
      songs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)) ~/ 60000;
  return minutes < 60
      ? '$minutes dk'
      : '${minutes ~/ 60} sa ${minutes % 60} dk';
}
