import 'package:flutter/widgets.dart';

/// Each tab keeps its own detail handler, even while another tab is visible.
class TabBackHost extends InheritedWidget {
  const TabBackHost({
    super.key,
    required this.handlerKey,
    required super.child,
  });
  final GlobalKey<TabBackDetailState> handlerKey;

  @override
  bool updateShouldNotify(TabBackHost oldWidget) =>
      handlerKey != oldWidget.handlerKey;
}

class TabBackScope extends StatelessWidget {
  const TabBackScope({
    super.key,
    required this.hasDetail,
    required this.back,
    required this.child,
  });
  final bool hasDetail;
  final VoidCallback back;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<TabBackHost>();
    if (host != null) {
      return TabBackDetail(key: host.handlerKey, scope: this);
    }
    return PopScope(
      canPop: !hasDetail,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && hasDetail) back();
      },
      child: child,
    );
  }
}

class TabBackDetail extends StatefulWidget {
  const TabBackDetail({super.key, required this.scope});
  final TabBackScope scope;
  @override
  State<TabBackDetail> createState() => TabBackDetailState();
}

class TabBackDetailState extends State<TabBackDetail> {
  bool back() {
    if (!widget.scope.hasDetail) return false;
    widget.scope.back();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.scope.child;
}
