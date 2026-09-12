import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommonsTrack {
  const CommonsTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.fileUrl,
    required this.sourcePageUrl,
    required this.mimeType,
    required this.licenseName,
    required this.licenseUrl,
    required this.credit,
    required this.description,
  });

  final int id;

  final String title;
  final String artist;

  final String fileUrl;
  final String sourcePageUrl;

  final String mimeType;

  final String licenseName;
  final String licenseUrl;

  final String credit;
  final String description;

  bool get canDownload {
    final license = licenseName
        .toLowerCase()
        .replaceAll('-', ' ');

    if (license.contains('noncommercial') ||
        license.contains(' nc ')) {
      return false;
    }

    return license.contains('cc0') ||
        license.contains('public domain') ||
        license.contains('cc by');
  }
}

class DownloadedCommonsTrack {
  const DownloadedCommonsTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.localPath,
    required this.sourcePageUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.credit,
  });

  final int id;

  final String title;
  final String artist;

  final String localPath;

  final String sourcePageUrl;

  final String licenseName;
  final String licenseUrl;

  final String credit;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'localPath': localPath,
      'sourcePageUrl': sourcePageUrl,
      'licenseName': licenseName,
      'licenseUrl': licenseUrl,
      'credit': credit,
    };
  }

  factory DownloadedCommonsTrack.fromJson(
    Map<String, dynamic> json,
  ) {
    return DownloadedCommonsTrack(
      id: int.tryParse(
            json['id']?.toString() ?? '',
          ) ??
          0,
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      localPath:
          json['localPath']?.toString() ?? '',
      sourcePageUrl:
          json['sourcePageUrl']?.toString() ?? '',
      licenseName:
          json['licenseName']?.toString() ?? '',
      licenseUrl:
          json['licenseUrl']?.toString() ?? '',
      credit:
          json['credit']?.toString() ?? '',
    );
  }
}

class WikimediaMusicService {
  const WikimediaMusicService();

  static const String _host =
      'commons.wikimedia.org';

  static const String _apiPath =
      '/w/api.php';

  static const String _downloadsKey =
      'b_music02_wikimedia_downloads';

  Future<List<CommonsTrack>> searchMusic(
    String query, {
    int limit = 30,
  }) async {
    final cleaned =
        query.trim();

    final searchText =
        cleaned.isEmpty
            ? 'music filetype:audio'
            : '$cleaned filetype:audio';

    final uri = Uri.https(
      _host,
      _apiPath,
      {
        'action': 'query',
        'format': 'json',
        'formatversion': '2',

        'generator': 'search',

        'gsrsearch': searchText,

        'gsrnamespace': '6',

        'gsrlimit': '$limit',

        'prop': 'imageinfo|info',

        'inprop': 'url',

        'iiprop':
            'url|mime|size|extmetadata',

        'iiextmetadatalanguage':
            'en',

        'iiextmetadatafilter':
            'Artist|Credit|LicenseShortName|LicenseUrl|AttributionRequired|UsageTerms|ImageDescription',
      },
    );

    final response =
        await http
            .get(
              uri,
              headers: const {
                'Accept':
                    'application/json',
                'User-Agent':
                    'B_music02/0.1 Android',
              },
            )
            .timeout(
              const Duration(
                seconds: 25,
              ),
            );

    if (response.statusCode != 200) {
      throw Exception(
        'Wikimedia HTTP ${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(
      utf8.decode(
        response.bodyBytes,
      ),
    );

    if (decoded is! Map) {
      throw Exception(
        'Wikimedia yanıtı okunamadı.',
      );
    }

    final queryData =
        decoded['query'];

    if (queryData is! Map) {
      return [];
    }

    final pages =
        queryData['pages'];

    if (pages is! List) {
      return [];
    }

    final result =
        <CommonsTrack>[];

    for (final pageData in pages) {
      if (pageData is! Map) {
        continue;
      }

      final page =
          Map<String, dynamic>.from(
        pageData,
      );

      final imageInfoList =
          page['imageinfo'];

      if (imageInfoList is! List ||
          imageInfoList.isEmpty) {
        continue;
      }

      final firstInfo =
          imageInfoList.first;

      if (firstInfo is! Map) {
        continue;
      }

      final info =
          Map<String, dynamic>.from(
        firstInfo,
      );

      final mime =
          info['mime']
                  ?.toString()
                  .toLowerCase() ??
              '';

      if (!_supportedAudioMime(
        mime,
      )) {
        continue;
      }

      final fileUrl =
          info['url']?.toString() ?? '';

      if (fileUrl.isEmpty) {
        continue;
      }

      final extMetadata =
          info['extmetadata'];

      final metadata =
          extMetadata is Map
              ? Map<String, dynamic>.from(
                  extMetadata,
                )
              : <String, dynamic>{};

      final rawTitle =
          page['title']?.toString() ?? '';

      final title =
          _cleanFileTitle(
        rawTitle,
      );

      final artist =
          _cleanHtml(
        _metadataValue(
          metadata,
          'Artist',
        ),
      );

      final credit =
          _cleanHtml(
        _metadataValue(
          metadata,
          'Credit',
        ),
      );

      final licenseName =
          _cleanHtml(
        _metadataValue(
          metadata,
          'LicenseShortName',
        ),
      );

      final licenseUrl =
          _cleanHtml(
        _metadataValue(
          metadata,
          'LicenseUrl',
        ),
      );

      final description =
          _cleanHtml(
        _metadataValue(
          metadata,
          'ImageDescription',
        ),
      );

      final fullUrl =
          page['fullurl']?.toString() ??
              'https://commons.wikimedia.org/wiki/${Uri.encodeComponent(rawTitle)}';

      result.add(
        CommonsTrack(
          id:
              int.tryParse(
                page['pageid']
                        ?.toString() ??
                    '',
              ) ??
              0,

          title:
              title.isEmpty
                  ? 'Bilinmeyen Müzik'
                  : title,

          artist:
              artist.isEmpty
                  ? 'Wikimedia Commons'
                  : artist,

          fileUrl:
              fileUrl,

          sourcePageUrl:
              fullUrl,

          mimeType:
              mime,

          licenseName:
              licenseName.isEmpty
                  ? 'Lisans belirtilmemiş'
                  : licenseName,

          licenseUrl:
              licenseUrl,

          credit:
              credit,

          description:
              description,
        ),
      );
    }

    return result;
  }

  bool _supportedAudioMime(
    String mime,
  ) {
    return mime.contains('audio') ||
        mime.contains('ogg') ||
        mime.contains('mpeg') ||
        mime.contains('mp3') ||
        mime.contains('flac') ||
        mime.contains('wav') ||
        mime.contains('opus');
  }

  String _metadataValue(
    Map<String, dynamic> metadata,
    String key,
  ) {
    final value =
        metadata[key];

    if (value is Map) {
      return value['value']
              ?.toString() ??
          '';
    }

    return '';
  }

  String _cleanFileTitle(
    String value,
  ) {
    var result =
        value.replaceFirst(
      RegExp(
        r'^File:',
        caseSensitive: false,
      ),
      '',
    );

    result =
        result.replaceFirst(
      RegExp(
        r'\.(ogg|oga|mp3|wav|flac|opus|m4a|webm)$',
        caseSensitive: false,
      ),
      '',
    );

    result =
        result.replaceAll(
      '_',
      ' ',
    );

    return result.trim();
  }

  String _cleanHtml(
    String value,
  ) {
    return value
        .replaceAll(
          RegExp(
            r'<[^>]*>',
          ),
          ' ',
        )
        .replaceAll(
          '&amp;',
          '&',
        )
        .replaceAll(
          '&quot;',
          '"',
        )
        .replaceAll(
          '&#39;',
          "'",
        )
        .replaceAll(
          '&nbsp;',
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\s+',
          ),
          ' ',
        )
        .trim();
  }

  Future<DownloadedCommonsTrack> downloadTrack(
    CommonsTrack track,
  ) async {
    if (!track.canDownload) {
      throw Exception(
        'Bu parçanın lisansı indirme filtresine uygun değil.',
      );
    }

    final appDirectory =
        await getApplicationDocumentsDirectory();

    final musicDirectory =
        Directory(
      '${appDirectory.path}/b_music02_music',
    );

    if (!await musicDirectory.exists()) {
      await musicDirectory.create(
        recursive: true,
      );
    }

    final extension =
        _extensionFor(
      track.fileUrl,
      track.mimeType,
    );

    var safeTitle =
        track.title
            .replaceAll(
              RegExp(
                r'[^\w\s\-]',
                unicode: true,
              ),
              '',
            )
            .replaceAll(
              RegExp(
                r'\s+',
              ),
              '_',
            );

    if (safeTitle.isEmpty) {
      safeTitle =
          'music_${track.id}';
    }

    if (safeTitle.length > 60) {
      safeTitle =
          safeTitle.substring(
        0,
        60,
      );
    }

    final file =
        File(
      '${musicDirectory.path}/${track.id}_$safeTitle$extension',
    );

    if (!await file.exists()) {
      final client =
          http.Client();

      try {
        final request =
            http.Request(
          'GET',
          Uri.parse(
            track.fileUrl,
          ),
        );

        request.headers.addAll(
          const {
            'User-Agent':
                'B_music02/0.1 Android',
          },
        );

        final response =
            await client
                .send(
                  request,
                )
                .timeout(
                  const Duration(
                    seconds: 60,
                  ),
                );

        if (response.statusCode < 200 ||
            response.statusCode >= 300) {
          throw Exception(
            'İndirme HTTP ${response.statusCode}',
          );
        }

        final sink =
            file.openWrite();

        try {
          await response.stream.pipe(
            sink,
          );
        } catch (e) {
          if (await file.exists()) {
            await file.delete();
          }

          rethrow;
        }
      } finally {
        client.close();
      }
    }

    final downloaded =
        DownloadedCommonsTrack(
      id:
          track.id,

      title:
          track.title,

      artist:
          track.artist,

      localPath:
          file.path,

      sourcePageUrl:
          track.sourcePageUrl,

      licenseName:
          track.licenseName,

      licenseUrl:
          track.licenseUrl,

      credit:
          track.credit,
    );

    await _saveDownload(
      downloaded,
    );

    return downloaded;
  }

  Future<void> _saveDownload(
    DownloadedCommonsTrack track,
  ) async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final current =
        await getDownloads();

    current.removeWhere(
      (item) =>
          item.id ==
          track.id,
    );

    current.insert(
      0,
      track,
    );

    await prefs.setString(
      _downloadsKey,
      jsonEncode(
        current
            .map(
              (item) =>
                  item.toJson(),
            )
            .toList(),
      ),
    );
  }

  Future<List<DownloadedCommonsTrack>>
      getDownloads() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final raw =
        prefs.getString(
      _downloadsKey,
    );

    if (raw == null ||
        raw.isEmpty) {
      return [];
    }

    try {
      final decoded =
          jsonDecode(
        raw,
      );

      if (decoded is! List) {
        return [];
      }

      final result =
          <DownloadedCommonsTrack>[];

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final track =
            DownloadedCommonsTrack
                .fromJson(
          Map<String, dynamic>.from(
            item,
          ),
        );

        if (track.localPath.isEmpty) {
          continue;
        }

        final file =
            File(
          track.localPath,
        );

        if (await file.exists()) {
          result.add(
            track,
          );
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteDownload(
    DownloadedCommonsTrack track,
  ) async {
    final file =
        File(
      track.localPath,
    );

    if (await file.exists()) {
      await file.delete();
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    final current =
        await getDownloads();

    current.removeWhere(
      (item) =>
          item.id ==
          track.id,
    );

    await prefs.setString(
      _downloadsKey,
      jsonEncode(
        current
            .map(
              (item) =>
                  item.toJson(),
            )
            .toList(),
      ),
    );
  }

  String _extensionFor(
    String url,
    String mime,
  ) {
    try {
      final path =
          Uri.parse(url).path;

      final lastDot =
          path.lastIndexOf('.');

      if (lastDot >= 0) {
        final ext =
            path.substring(
          lastDot,
        );

        if (ext.length >= 3 &&
            ext.length <= 7) {
          return ext;
        }
      }
    } catch (_) {}

    if (mime.contains('mpeg')) {
      return '.mp3';
    }

    if (mime.contains('flac')) {
      return '.flac';
    }

    if (mime.contains('wav')) {
      return '.wav';
    }

    if (mime.contains('opus')) {
      return '.opus';
    }

    return '.ogg';
  }
}
