import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../profile/public_user_profile_screen.dart';

class ExploreUsersScreen extends StatefulWidget {
  const ExploreUsersScreen({
    super.key,
    required this.onRequestLogin,
  });

  final Future<void> Function() onRequestLogin;

  @override
  State<ExploreUsersScreen> createState() => _ExploreUsersScreenState();
}

class _ExploreUsersScreenState extends State<ExploreUsersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _requestsLoading = true;
  String? _error;
  List<_Person> _people = const [];
  List<_IncomingRequest> _requests = const [];
  Set<String> _followingIds = <String>{};
  Set<String> _pendingIds = <String>{};

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get _user => _supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _requestsLoading = false;
        });
      }
      return;
    }
    await Future.wait([
      _loadPeople(_controller.text),
      _loadRequests(),
      _loadRelations(),
    ]);
  }

  Future<void> _loadRelations() async {
    final user = _user;
    if (user == null) return;
    final follows = await _supabase
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', user.id);
    final pending = await _supabase
        .from('follow_requests')
        .select('target_id')
        .eq('requester_id', user.id)
        .eq('status', 'pending');
    if (!mounted) return;
    setState(() {
      _followingIds = (follows as List)
          .map((e) => (e as Map)['following_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
      _pendingIds = (pending as List)
          .map((e) => (e as Map)['target_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
    });
  }

  Future<void> _loadPeople(String query) async {
    final user = _user;
    if (user == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      dynamic request = _supabase
          .from('profiles')
          .select('id,username,display_name,avatar_url,bio')
          .eq('account_status', 'active')
          .neq('id', user.id);
      final clean = query.trim().replaceAll('%', '').replaceAll(',', ' ');
      if (clean.isNotEmpty) {
        request = request.or('username.ilike.%$clean%,display_name.ilike.%$clean%');
      }
      final rows = await request.order('display_name').limit(40);
      final people = (rows as List)
          .map((e) => _Person.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Kullanıcılar yüklenemedi.';
      });
    }
  }

  Future<void> _loadRequests() async {
    final user = _user;
    if (user == null) return;
    if (mounted) setState(() => _requestsLoading = true);
    try {
      final rows = await _supabase
          .from('follow_requests')
          .select('id,requester_id,created_at')
          .eq('target_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final result = <_IncomingRequest>[];
      for (final raw in (rows as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final requesterId = map['requester_id']?.toString() ?? '';
        if (requesterId.isEmpty) continue;
        final profile = await _supabase
            .from('profiles')
            .select('id,username,display_name,avatar_url,bio')
            .eq('id', requesterId)
            .maybeSingle();
        if (profile == null) continue;
        result.add(
          _IncomingRequest(
            id: map['id']?.toString() ?? '',
            person: _Person.fromMap(Map<String, dynamic>.from(profile)),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _requests = result;
        _requestsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _requestsLoading = false);
    }
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _loadPeople(value));
  }

  Future<void> _openProfile(_Person person) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicUserProfileScreen(
          userId: person.id,
          username: person.username,
          displayName: person.displayName,
          avatarUrl: person.avatarUrl,
          bio: person.bio,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _sendRequest(_Person person) async {
    if (_user == null) {
      await widget.onRequestLogin();
      return;
    }
    try {
      await _supabase.rpc('send_follow_request', params: {'p_target_id': person.id});
      if (!mounted) return;
      setState(() => _pendingIds.add(person.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${person.name} kullanıcısına takip isteği gönderildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip isteği gönderilemedi.')),
      );
    }
  }

  Future<void> _unfollow(_Person person) async {
    final user = _user;
    if (user == null) return;
    await _supabase
        .from('user_follows')
        .delete()
        .eq('follower_id', user.id)
        .eq('following_id', person.id);
    if (mounted) setState(() => _followingIds.remove(person.id));
  }

  Future<void> _respond(_IncomingRequest request, bool accept) async {
    try {
      await _supabase.rpc('respond_follow_request', params: {
        'p_request_id': request.id,
        'p_accept': accept,
      });
      await _loadRequests();
      await _loadRelations();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip isteği güncellenemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _user == null
            ? _guest()
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
                  children: [
                    const Text(
                      'Keşfet',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    _searchField(),
                    const SizedBox(height: 18),
                    if (_requestsLoading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.neonPurple,
                      )
                    else if (_requests.isNotEmpty) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Gelen Takip İstekleri',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.neonPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_requests.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ..._requests.map(_requestTile),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      _controller.text.trim().isEmpty
                          ? 'Kullanıcıları Keşfet'
                          : 'Arama Sonuçları',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 9),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.neonPurple),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(_error!, style: const TextStyle(color: Colors.white60)),
                      )
                    else if (_people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 42),
                        child: Center(child: Text('Kullanıcı bulunamadı.')),
                      )
                    else
                      ..._people.map(_personTile),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _guest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_alt_rounded, size: 62, color: AppColors.neonPurple),
            const SizedBox(height: 15),
            const Text(
              'Keşfet için giriş yap',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'Kullanıcıları bulmak, takip isteği göndermek ve hikâyeleri görmek için hesabınla giriş yap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => widget.onRequestLogin(),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2D40)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _changed,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Kullanıcı adı veya isim ara',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _controller.clear();
                    _changed('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _personTile(_Person person) {
    final following = _followingIds.contains(person.id);
    final pending = _pendingIds.contains(person.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF24273A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openProfile(person),
              child: Row(
                children: [
                  _avatar(person, 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (person.username.isNotEmpty)
                          Text(
                            '@${person.username}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        if (person.bio.isNotEmpty)
                          Text(
                            person.bio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (following)
            OutlinedButton(
              onPressed: () => _unfollow(person),
              child: const Text('Takiptesin'),
            )
          else
            FilledButton(
              onPressed: pending ? null : () => _sendRequest(person),
              child: Text(pending ? 'İstek Gönderildi' : 'Takip Et'),
            ),
        ],
      ),
    );
  }

  Widget _requestTile(_IncomingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF171526),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openProfile(request.person),
              child: Row(
                children: [
                  _avatar(request.person, 45),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.person.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Seni takip etmek istiyor',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reddet',
            onPressed: () => _respond(request, false),
            icon: const Icon(Icons.close_rounded, color: Colors.white60),
          ),
          IconButton(
            tooltip: 'Kabul et',
            onPressed: () => _respond(request, true),
            icon: const Icon(Icons.check_circle_rounded, color: AppColors.neonPurple),
          ),
        ],
      ),
    );
  }

  Widget _avatar(_Person person, double size) {
    if (person.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFF24163C),
        backgroundImage: NetworkImage(person.avatarUrl),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF24163C),
      child: Text(
        person.name.isEmpty ? '?' : person.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.neonPurple,
        ),
      ),
    );
  }
}

class _Person {
  const _Person({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;

  String get name => displayName.trim().isNotEmpty
      ? displayName.trim()
      : (username.trim().isNotEmpty ? username.trim() : 'B_music02 Kullanıcısı');

  factory _Person.fromMap(Map<String, dynamic> map) => _Person(
        id: map['id']?.toString() ?? '',
        username: map['username']?.toString() ?? '',
        displayName: map['display_name']?.toString() ?? '',
        avatarUrl: map['avatar_url']?.toString() ?? '',
        bio: map['bio']?.toString() ?? '',
      );
}

class _IncomingRequest {
  const _IncomingRequest({required this.id, required this.person});

  final String id;
  final _Person person;
}
