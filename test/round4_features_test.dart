import 'dart:convert';

import 'package:b_music02/core/l10n/app_text.dart';
import 'package:b_music02/core/platform/feature_bridge.dart';
import 'package:b_music02/core/services/night_light.dart';
import 'package:b_music02/core/services/playlist_qr.dart';
import 'package:b_music02/core/services/song_letters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_audio_query/on_audio_query.dart';

SongModel song(int id, String title, String artist) => SongModel({
      '_id': id,
      'title': title,
      'artist': artist,
      '_data': '/music/$title.mp3',
      'duration': 200000,
      '_display_name': '$title.mp3',
    });

void main() {
  group('QR liste', () {
    final library = [
      song(1, 'Altın Saat', 'Lumen Trio'),
      song(2, 'Gece Yolculuğu', 'Neon Rüyası'),
      song(3, 'Kuzey Rüzgârı', 'Lumen Trio'),
      song(4, 'Altın Saat', 'Başka Grup'),
    ];

    test('round-trips through the web link and the app link', () {
      final link = PlaylistQr.encode('Yol Müziği', library.take(3).toList());
      expect(link, startsWith('https://bmusic02-app.web.app/l#'));
      final shared = PlaylistQr.decode(link)!;
      expect(shared.name, 'Yol Müziği');
      expect(shared.songs.first, ('Altın Saat', 'Lumen Trio'));
      final data = Uri.parse(link).fragment;
      expect(PlaylistQr.decode('bmusic://liste?d=$data')!.songs.length, 3);
      expect(PlaylistQr.decode('https://example.com'), isNull);
      expect(PlaylistQr.decode('rastgele yazı'), isNull);
    });

    test('stays small enough for a scannable QR code', () {
      final many = [
        for (var i = 0; i < 80; i++) song(i, 'Çok uzun bir şarkı adı numara $i', 'Sanatçı $i')
      ];
      final link = PlaylistQr.encode('Uzun', many);
      expect(PlaylistQr.decode(link)!.songs.length, PlaylistQr.maxSongs);
      expect(link.length, lessThan(1800));
    });

    test('matches local songs by title, preferring the artist', () {
      const shared = SharedPlaylist('L', [
        ('altin saat', 'başka grup'),
        ('Gece Yolculuğu', ''),
        ('Yok Böyle Şarkı', 'X'),
      ]);
      final found = PlaylistQr.match(shared, library);
      expect(found.map((s) => s.id), [4, 2]);
    });

    test('never overwrites an existing playlist name', () {
      expect(PlaylistQr.uniqueName('Yol', ['Yol', 'Yol (2)']), 'Yol (3)');
      expect(PlaylistQr.uniqueName('Yeni', ['Yol']), 'Yeni');
    });
  });

  group('Şarkı mektubu', () {
    test('parses web and app links', () {
      const id = 'AbCdEfGhIjKlMnOpQrSt';
      expect(SongLetters.idFromLink('https://bmusic02-app.web.app/m/$id'), id);
      expect(SongLetters.idFromLink('bmusic://mektup/$id'), id);
      expect(SongLetters.idFromLink('bmusic://mektup/kisa'), isNull);
      expect(SongLetters.webLink(id), 'https://bmusic02-app.web.app/m/$id');
    });

    test('creates a letter with the typed sender name and server time', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      final id = await SongLetters(client: client).send(
          sender: ' Abidin ', message: 'Bu şarkı seni hatırlatıyor 💛', title: 'Altın Saat',
          artist: 'Lumen Trio', cover: [1, 2, 3]);
      expect(id, matches(RegExp(r'^[A-Za-z0-9]{20}$')));
      final write = (sent['writes'] as List).single as Map;
      final fields = (write['update'] as Map)['fields'] as Map;
      expect(fields['sender'], {'stringValue': 'Abidin'});
      expect(fields.containsKey('clip'), isFalse);
      expect(fields['cover'], {'stringValue': base64Encode([1, 2, 3])});
      expect(write['currentDocument'], {'exists': false});
      expect((write['update'] as Map)['name'], endsWith('/letters/$id'));
    });

    test('requires a manually typed sender name', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      expect(
          () => SongLetters(client: client)
              .send(sender: '  ', message: 'Merhaba', title: 'Altın Saat'),
          throwsA(isA<LetterException>()));
    });

    test('reads a letter back', () async {
      final client = MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'fields': {
              'sender': {'stringValue': 'Abidin'},
              'message': {'stringValue': 'Selam'},
              'title': {'stringValue': 'Altın Saat'},
              'clip': {'stringValue': base64Encode([9, 9])},
            }
          })),
          200));
      final letter = await SongLetters(client: client).fetch('AbCdEfGhIjKlMnOpQrSt');
      expect(letter.sender, 'Abidin');
      expect(letter.clip, [9, 9]);
      expect(letter.cover, isNull);
    });
  });

  test('gece ışığı and ses yükseltici ranges', () {
    expect(NightLight.dimFor(1), 0);
    expect(NightLight.dimFor(.1), lessThanOrEqualTo(.7));
    expect(NightLight.warmFor(1), closeTo(.32, 1e-9));
    expect(FeatureBridge.boostDb(100), 0);
    expect(FeatureBridge.boostDb(200), 10);
    expect(pseudoWaveform(3, 40), hasLength(40));
  });

  test('new screens are translated in every language', () {
    for (final text in [
      'Hikâyede paylaş',
      'Şarkı mektubu',
      'QR okut',
      'Ses yükseltici',
      'Gece ışığı',
      'Mini müzik baloncuğu',
      'B Music’te dinle',
      'Adın (gönderen)',
    ]) {
      for (final lang in ['en', 'ku', 'ckb', 'ar']) {
        expect(translate(text, lang), isNot(text), reason: '$text/$lang');
      }
    }
  });
}
