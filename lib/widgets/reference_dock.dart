import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app.dart';
import 'installed_app_icon.dart';
import 'reference_chrome.dart';
import 'original_app_frame.dart';

class ReferenceDock extends StatefulWidget {
  final List<App> apps;
  final ValueChanged<App> onLaunch;
  final VoidCallback onEdit, onLeftBoundary;
  final ValueChanged<double> onUp;
  final FocusNode firstFocus;
  final ValueChanged<App>? onAppOptions;
  final ValueChanged<FocusNode>? onAppFocused;
  const ReferenceDock({
    super.key,
    required this.apps,
    required this.onLaunch,
    required this.onEdit,
    required this.onLeftBoundary,
    required this.onUp,
    required this.firstFocus,
    this.onAppOptions,
    this.onAppFocused,
  });
  @override
  State<ReferenceDock> createState() => _ReferenceDockState();
}

class _ReferenceDockState extends State<ReferenceDock> {
  final _nodes = List.generate(
    6,
    (i) => FocusNode(debugLabel: 'dock-slot-${i + 2}'),
  );
  FocusNode _node(int i) => i == 0 ? widget.firstFocus : _nodes[i - 1];
  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReferenceGlass(
    radius: 22,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 6 * 12) / 7;
            return Row(
              children: List.generate(7, (i) {
                final app = i < widget.apps.length ? widget.apps[i] : null;
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : 12),
                  child: SizedBox(
                    width: width,
                    child: ReferenceFocusable(
                      key: ValueKey(
                        app == null
                            ? 'dock-empty-$i'
                            : 'dock-${app.packageName}',
                      ),
                      focusNode: _node(i),
                      onFocusChanged: (focused) {
                        if (focused) widget.onAppFocused?.call(_node(i));
                      },
                      label: app?.name ?? 'إضافة تطبيق للمفضلة',
                      onLongPress: app == null
                          ? widget.onEdit
                          : () => widget.onAppOptions?.call(app),
                      onPressed: app == null
                          ? widget.onEdit
                          : () => widget.onLaunch(app),
                      onKey: (event) {
                        if (event is KeyDownEvent &&
                            [
                              LogicalKeyboardKey.contextMenu,
                              LogicalKeyboardKey.keyM,
                              LogicalKeyboardKey.gameButtonX,
                            ].contains(event.logicalKey)) {
                          app == null
                              ? widget.onEdit()
                              : widget.onAppOptions?.call(app);
                          return KeyEventResult.handled;
                        }
                        return referenceDirections(
                          event,
                          left: () => i == 0
                              ? widget.onLeftBoundary()
                              : _node(i - 1).requestFocus(),
                          right: () =>
                              i < 6 ? _node(i + 1).requestFocus() : null,
                          up: () =>
                              widget.onUp(255 + i * (width + 12) + width / 2),
                          down: () {},
                        );
                      },
                      builder: (context, focused) => GestureDetector(
                        onLongPress: app == null
                            ? widget.onEdit
                            : () => widget.onAppOptions?.call(app),
                        child: OriginalAppFrame(
                          focused: focused,
                          child: app == null
                              ? const Center(
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                )
                              : InstalledAppIcon(
                                  key: ValueKey(
                                    '${app.packageName}-${app.version}',
                                  ),
                                  app: app,
                                  preferTvBanner: true,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    ),
  );
}
