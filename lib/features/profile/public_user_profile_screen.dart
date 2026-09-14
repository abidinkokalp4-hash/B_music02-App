import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/story_service.dart';
import '../../core/theme/app_theme.dart';
import '../stories/story_viewer_screen.dart';

class PublicUserProfileScreen extends StatefulWidget {
  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });

  final String userId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;

  @override
  State<PublicUserProfileScreen> createState() => _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  final StoryService _stories = StoryService.instance;

  bool _loading = true;
  bool _actionLoading = false;
  bool _following = false;
  bool _pending = false;
  int _followers = 0;
  int _followingCount = 0;
  List<MusicStory> _activeStories = const [];

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _me => _supabase.auth.currentUser;

  String get _name {
    final display = widget.displayName.trim();
    if (display.isNotEmpty) return display;
    final username = widget.username.trim();
    return username.isEmpty ? 'B_music02 Kullanıcısı' : username;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final followerRows = await _supabase
          .from('user_follows')
          .select('follower_id')
          .eq('following_id', widget.userId);
      final followingRows = await _supabase
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', widget.userId);

      bool following = false;
      bool pending = false;
      final me = _me;
      if (me != null && me.id != widget.userId) {
        final follow = await _supabase
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', me.id)
            .eq('following_id', widget.userId)
            .maybeSingle();
        following = follow != null;

        if (!following) {
          final request = await _supabase
              .from('follow_requests')
              .select('id')
              .eq('requester_id', me.id)
              .eq('target_id', widget.userId)
              .eq('status', 'pending')
              .maybeSingle();
          pending = request != null;
        }
      }

      final stories = await _stories.storiesForUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _followers = (followerRows as List).length;
        _followingCount = (followingRows as List).length;
        _following = following;
        _pending = pending;
        _activeStories = stories;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _followAction() async {
    final me = _me;
    if (me == null || me.id == widget.userId || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      if (_following) {
        await _supabase
            .from('user_follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', widget.userId);
        if (!mounted) return;
        setState(() {
          _following = false;
          _pending = false;
          if (_followers > 0) _followers--;
        });
      } else if (!_pending) {
        await _supabase.rpc(
          'send_follow_request',
          params: {'p_target_id': widget.userId},
        );
        if (!mounted) return;
        setState(() => _pending = true);
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _openStories() async {
    if (_activeStories.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(stories: _activeStories),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = _me?.id == widget.userId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.username.trim().isEmpty ? _name : '@${widget.username.trim()}'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.neonPurple,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Center(
              child: GestureDetector(
                onTap: _activeStories.isEmpty ? null : _openStories,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _activeStories.isEmpty
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.neonPurple, AppColors.neonPink],
                          ),
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF24163C),
                    backgroundImage: widget.avatarUrl.trim().isEmpty
                        ? null
                        : NetworkImage(widget.avatarUrl.trim()),
                    child: widget.avatarUrl.trim().isEmpty
                        ? Text(
                            _name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.neonPurple,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Center(
              child: Text(
                _name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.username.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Center(
                child: Text(
                  '@${widget.username.trim()}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            if (widget.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.bio.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _stat('Takipçi', _followers)),
                Container(width: 1, height: 34, color: const Color(0xFF2A2D40)),
                Expanded(child: _stat('Takip', _followingCount)),
                Container(width: 1, height: 34, color: const Color(0xFF2A2D40)),
                Expanded(child: _stat('Hikâye', _activeStories.length)),
              ],
            ),
            const SizedBox(height: 20),
            if (!isMe)
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _actionLoading || _pending ? null : _followAction,
                  icon: _actionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_following ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded),
                  label: Text(
                    _following
                        ? 'Takibi Bırak'
                        : _pending
                            ? 'İstek Gönderildi'
                            : 'Takip Et',
                  ),
                ),
              ),
            if (_loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
            ] else if (_activeStories.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Aktif Hikâyeler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ..._activeStories.asMap().entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: entry.value.thumbnailUrl.isEmpty
                            ? const SizedBox(
                                width: 52,
                                height: 52,
                                child: ColoredBox(
                                  color: Color(0xFF24163C),
                                  child: Icon(Icons.music_note_rounded),
                                ),
                              )
                            : Image.network(
                                entry.value.thumbnailUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                      ),
                      title: Text(entry.value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(entry.value.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.play_circle_outline_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            stories: _activeStories,
                            initialIndex: entry.key,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
      ],
    );
  }
}
