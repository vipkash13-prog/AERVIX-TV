import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app.dart';
import 'installed_app_icon.dart';
import 'reference_chrome.dart';

class ReferenceDock extends StatefulWidget {
  final List<App> apps;
  final ValueChanged<App> onLaunch;
  final VoidCallback onAllApps;
  final VoidCallback onLeftBoundary;
  final ValueChanged<double> onUp;
  final FocusNode firstFocus;
  final FocusNode allAppsFocus;
  const ReferenceDock({
    super.key,
    required this.apps,
    required this.onLaunch,
    required this.onAllApps,
    required this.onLeftBoundary,
    required this.onUp,
    required this.firstFocus,
    required this.allAppsFocus,
  });
  @override
  State<ReferenceDock> createState() => _ReferenceDockState();
}

class _ReferenceDockState extends State<ReferenceDock> {
  final _controller = ScrollController();
  final _nodes = <String, FocusNode>{};
  int _lastIndex = 7;
  FocusNode _node(int index) => index == 0
      ? widget.firstFocus
      : _nodes.putIfAbsent(
          widget.apps[index].packageName,
          () => FocusNode(debugLabel: 'dock-${widget.apps[index].packageName}'),
        );
  @override
  void didUpdateWidget(covariant ReferenceDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final packages = widget.apps.map((a) => a.packageName).toSet();
    final removed = _nodes.keys
        .where((key) => !packages.contains(key))
        .toList();
    for (final key in removed) {
      _nodes.remove(key)!.dispose();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _focus(int index) {
    if (widget.apps.isEmpty) {
      widget.allAppsFocus.requestFocus();
      return;
    }
    final target = index.clamp(0, widget.apps.length - 1);
    _lastIndex = target;
    if (_controller.hasClients) {
      final offset =
          (target * 113.0 - _controller.position.viewportDimension / 2 + 56)
              .clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
    _node(target).requestFocus();
  }

  Color _color(App app) {
    final n = '${app.name} ${app.packageName}'.toLowerCase();
    if (n.contains('nuvio')) return const Color(0xFF39126A);
    if (n.contains('stremio')) return const Color(0xFF24124D);
    if (n.contains('shahid') || n.contains('mbc'))
      return const Color(0xFF00434C);
    if (n.contains('yacin')) return const Color(0xFF920C12);
    if (n.contains('vlc') || n.contains('videolan'))
      return const Color(0xFFC77009);
    if (n.contains('aiostream')) return const Color(0xFF064675);
    return const Color(0xFF121720);
  }

  @override
  Widget build(BuildContext context) => ReferenceGlass(
    radius: 22,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: widget.apps.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد تطبيقات مثبتة',
                        style: TextStyle(fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      itemExtent: 113,
                      cacheExtent: 226,
                      itemCount: widget.apps.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final app = widget.apps[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ReferenceFocusable(
                            key: ValueKey('dock-${app.packageName}'),
                            focusNode: _node(index),
                            label: app.name,
                            onPressed: () => widget.onLaunch(app),
                            onFocusChanged: (focused) {
                              if (focused) _lastIndex = index;
                            },
                            onKey: (event) => referenceDirections(
                              event,
                              left: () => index == 0
                                  ? widget.onLeftBoundary()
                                  : _focus(index - 1),
                              right: () => index == widget.apps.length - 1
                                  ? widget.allAppsFocus.requestFocus()
                                  : _focus(index + 1),
                              up: () => widget.onUp(
                                255 +
                                    index * 113 -
                                    (_controller.hasClients
                                        ? _controller.offset
                                        : 0) +
                                    51,
                              ),
                              down: () {},
                            ),
                            builder: (context, focused) => ReferenceGlass(
                              radius: 15,
                              focused: focused,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color.lerp(
                                        _color(app),
                                        Colors.white,
                                        .16,
                                      )!,
                                      _color(app),
                                      Colors.black.withValues(alpha: .85),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: InstalledAppIcon(
                                    app: app,
                                    preferTvBanner: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 73,
              child: ReferenceFocusable(
                label: 'جميع التطبيقات',
                focusNode: widget.allAppsFocus,
                onPressed: widget.onAllApps,
                onKey: (event) => referenceDirections(
                  event,
                  left: () =>
                      _focus(math.min(_lastIndex, widget.apps.length - 1)),
                  up: () => widget.onUp(1200),
                  right: () {},
                  down: () {},
                ),
                builder: (context, focused) => ReferenceGlass(
                  radius: 15,
                  focused: focused,
                  child: const Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 35,
                      color: Color(0xFFE3E6EB),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
