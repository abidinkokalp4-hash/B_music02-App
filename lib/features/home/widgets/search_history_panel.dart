import 'package:flutter/material.dart';

import '../../../core/l10n/app_text.dart';
import '../../../core/services/search_history.dart';
import '../../../core/theme/aurora.dart';

/// Recent searches listed under a search field: tap to reuse, swipe or
/// trailing X to delete one, "Tümünü temizle" to wipe the list.
class SearchHistoryPanel extends StatefulWidget {
  const SearchHistoryPanel({
    super.key,
    required this.onSelect,
    this.history,
    this.visible = true,
  });
  final ValueChanged<String> onSelect;
  final SearchHistory? history;
  final bool visible;
  @override
  State<SearchHistoryPanel> createState() => _SearchHistoryPanelState();
}

class _SearchHistoryPanelState extends State<SearchHistoryPanel> {
  List<String> items = const [];

  SearchHistory get history => widget.history ?? SearchHistory.instance;

  @override
  void initState() {
    super.initState();
    history.load().then((v) { if (mounted) setState(() => items = v); });
  }

  Future<void> refresh() async {
    final v = await history.load();
    if (mounted) setState(() => items = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: AppText('Son aramalar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Aurora.textMuted))),
          TextButton(
            onPressed: () async {
              await history.clear();
              await refresh();
            },
            child: const AppText('Tümünü temizle', style: TextStyle(fontSize: 12)),
          ),
        ]),
        for (final q in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, size: 20, color: Aurora.textMuted),
            title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: tr('Arama geçmişinden sil'),
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () async {
                await history.remove(q);
                await refresh();
              },
            ),
            onTap: () => widget.onSelect(q),
          ),
      ]),
    );
  }
}
