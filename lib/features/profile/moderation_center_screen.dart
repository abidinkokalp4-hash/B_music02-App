import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({super.key});

  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  List<_ModerationReport> _reports = const [];
  Map<String, Map<String, dynamic>> _profiles = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final profileRows = await _supabase
          .from('profiles')
          .select('id, username, display_name, account_status, suspended_until');
      final profiles = <String, Map<String, dynamic>>{
        for (final raw in profileRows)
          raw['id'].toString(): Map<String, dynamic>.from(raw),
      };

      final values = await Future.wait<dynamic>([
        _supabase
            .from('message_reports')
            .select('id, reported_user_id, reason, details, message_snapshot, created_at, status')
            .eq('status', 'open')
            .order('created_at', ascending: false),
        _supabase
            .from('community_post_reports')
            .select('id, reported_user_id, reason, created_at, status')
            .eq('status', 'open')
            .order('created_at', ascending: false),
        _supabase
            .from('video_reports')
            .select('id, reason, details, created_at, status, video_id')
            .eq('status', 'open')
            .order('created_at', ascending: false),
        _supabase
            .from('user_reports')
            .select('id, reported_user_id, reason, details, created_at, status')
            .eq('status', 'open')
            .order('created_at', ascending: false),
      ]);

      final reports = <_ModerationReport>[];
      for (final raw in values[0] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        reports.add(_ModerationReport.fromMap('message', row));
      }
      for (final raw in values[1] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        reports.add(_ModerationReport.fromMap('post', row));
      }
      for (final raw in values[2] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        String? ownerId;
        final videoId = row['video_id']?.toString();
        if (videoId != null) {
          final video = await _supabase
              .from('community_videos')
              .select('user_id')
              .eq('id', videoId)
              .maybeSingle();
          ownerId = video?['user_id']?.toString();
        }
        reports.add(_ModerationReport.fromMap('video', row, reportedUserId: ownerId));
      }
      for (final raw in values[3] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        reports.add(_ModerationReport.fromMap('user', row));
      }

      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _reports = reports;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Moderasyon verileri yüklenemedi: $error');
    }
  }

  String _profileName(String? id) {
    if (id == null) return 'Bilinmeyen kullanıcı';
    final row = _profiles[id];
    if (row == null) return id;
    final display = row['display_name']?.toString().trim() ?? '';
    final username = row['username']?.toString() ?? 'kullanici';
    return display.isEmpty ? '@$username' : '$display (@$username)';
  }

  Future<void> _resolve(_ModerationReport report, {required bool removeContent}) async {
    try {
      await _supabase.rpc('moderator_resolve_report', params: {
        'p_kind': report.kind,
        'p_report_id': report.id,
        'p_remove_content': removeContent,
      });
      _message(removeContent ? 'Rapor çözüldü ve içerik kaldırıldı.' : 'Rapor çözüldü.');
      await _load();
    } catch (error) {
      _message('İşlem tamamlanamadı: $error');
    }
  }

  Future<void> _setUserStatus(String userId, String status) async {
    try {
      final until = status == 'suspended'
          ? DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String()
          : null;
      await _supabase.rpc('moderator_set_user_status', params: {
        'p_user_id': userId,
        'p_status': status,
        'p_suspended_until': until,
      });
      _message(
        switch (status) {
          'suspended' => 'Kullanıcı 7 gün askıya alındı.',
          'banned' => 'Kullanıcı kalıcı olarak engellendi.',
          _ => 'Kullanıcı yeniden aktifleştirildi.',
        },
      );
      await _load();
    } catch (error) {
      _message('Kullanıcı durumu değiştirilemedi: $error');
    }
  }

  Future<void> _actions(_ModerationReport report) async {
    final userId = report.reportedUserId;
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Wrap(
        children: [
          const ListTile(
            leading: Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold),
            title: Text('Moderasyon işlemleri'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: const Text('Raporu çözüldü olarak işaretle'),
            onTap: () => Navigator.pop(sheetContext, 'resolve'),
          ),
          if (report.kind != 'user')
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              title: const Text('İçeriği kaldır ve raporu kapat'),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          if (userId != null) ...[
            ListTile(
              leading: const Icon(Icons.timer_off_rounded),
              title: const Text('Kullanıcıyı 7 gün askıya al'),
              onTap: () => Navigator.pop(sheetContext, 'suspend'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
              title: const Text('Kullanıcıyı kalıcı engelle'),
              onTap: () => Navigator.pop(sheetContext, 'ban'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Kullanıcıyı aktifleştir'),
              onTap: () => Navigator.pop(sheetContext, 'active'),
            ),
          ],
        ],
      ),
    );

    if (result == 'resolve') await _resolve(report, removeContent: false);
    if (result == 'remove') await _resolve(report, removeContent: true);
    if (userId != null && result == 'suspend') await _setUserStatus(userId, 'suspended');
    if (userId != null && result == 'ban') await _setUserStatus(userId, 'banned');
    if (userId != null && result == 'active') await _setUserStatus(userId, 'active');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  IconData _kindIcon(String kind) {
    return switch (kind) {
      'post' => Icons.dynamic_feed_rounded,
      'video' => Icons.video_library_rounded,
      'user' => Icons.person_off_rounded,
      _ => Icons.chat_bubble_rounded,
    };
  }

  String _kindLabel(String kind) {
    return switch (kind) {
      'post' => 'Topluluk gönderisi',
      'video' => 'Topluluk videosu',
      'user' => 'Kullanıcı',
      _ => 'Mesaj',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderasyon Merkezi'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              child: _reports.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Icon(Icons.verified_rounded, color: AppColors.gold, size: 54),
                        SizedBox(height: 12),
                        Center(child: Text('Açık şikâyet yok.')),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                              child: Icon(_kindIcon(report.kind), color: AppColors.gold),
                            ),
                            title: Text(
                              '${_kindLabel(report.kind)} • ${report.reason}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text('Bildirilen: ${_profileName(report.reportedUserId)}'),
                                if (report.details?.trim().isNotEmpty == true)
                                  Text(report.details!, maxLines: 3, overflow: TextOverflow.ellipsis),
                                if (report.snapshot?.trim().isNotEmpty == true)
                                  Text('İçerik: ${report.snapshot}', maxLines: 3, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            trailing: const Icon(Icons.more_vert_rounded),
                            onTap: () => _actions(report),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ModerationReport {
  const _ModerationReport({
    required this.kind,
    required this.id,
    required this.reportedUserId,
    required this.reason,
    required this.details,
    required this.snapshot,
    required this.createdAt,
  });

  final String kind;
  final String id;
  final String? reportedUserId;
  final String reason;
  final String? details;
  final String? snapshot;
  final DateTime createdAt;

  factory _ModerationReport.fromMap(
    String kind,
    Map<String, dynamic> map, {
    String? reportedUserId,
  }) {
    return _ModerationReport(
      kind: kind,
      id: map['id'].toString(),
      reportedUserId: reportedUserId ?? map['reported_user_id']?.toString(),
      reason: map['reason']?.toString() ?? 'Şikâyet',
      details: map['details']?.toString(),
      snapshot: map['message_snapshot']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
