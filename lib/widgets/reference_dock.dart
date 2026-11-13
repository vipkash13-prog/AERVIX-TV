import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app.dart';
import 'installed_app_icon.dart';
import 'reference_chrome.dart';
import 'original_app_frame.dart';
import 'premium_glass.dart';

class ReferenceDock extends StatefulWidget {
  final List<App> apps;
  final ValueChanged<App> onLaunch;
  final VoidCallback onEdit, onLeftBoundary;
  final ValueChanged<double> onUp;
  final FocusNode firstFocus;
  final bool compactIcons, showNames;
  final double slotGap;
  final FocusNode? lastFocus;
  final VoidCallback? onRightBoundary;
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
    this.compactIcons = false,
    this.showNames = false,
    this.slotGap = 12,
    this.lastFocus,
    this.onRightBoundary,
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
  FocusNode _node(int i) => i == 0
      ? widget.firstFocus
      : i == 6 && widget.lastFocus != null
      ? widget.lastFocus!
      : _nodes[i - 1];
  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _frame(Widget child) =>
      widget.compactIcons ? child : ReferenceGlass(radius: 22, child: child);
  Widget _artFrame(bool focused, Widget child) => widget.compactIcons
      ? PremiumGlass(
          focused: focused,
          radius: 23,
          child: Center(child: child),
        )
      : OriginalAppFrame(focused: focused, child: child);
  @override
  Widget build(BuildContext context) => _frame(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 6 * widget.slotGap) / 7;
            return Row(
              children: List.generate(7, (i) {
                final app = i < widget.apps.length ? widget.apps[i] : null;
                return Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : widget.slotGap),
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
                          right: () => i < 6
                              ? _node(i + 1).requestFocus()
                              : widget.onRightBoundary?.call(),
                          up: () => widget.onUp(
                            255 + i * (width + widget.slotGap) + width / 2,
                          ),
                          down: () {},
                        );
                      },
                      builder: (context, focused) => GestureDetector(
                        onLongPress: app == null
                            ? widget.onEdit
                            : () => widget.onAppOptions?.call(app),
                        child: _artFrame(
                          focused,
                          app == null
                              ? const Center(
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                )
                              : widget.showNames
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    InstalledAppIcon(
                                      key: ValueKey(
                                        '${app.packageName}-${app.version}',
                                      ),
                                      app: app,
                                      preferTvBanner: !widget.compactIcons,
                                      size: widget.showNames
                                          ? 48
                                          : widget.compactIcons
                                          ? 62
                                          : 72,
                                    ),
                                    if (widget.showNames) ...[
                                      const SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: Text(
                                          app.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : InstalledAppIcon(
                                  key: ValueKey(
                                    '${app.packageName}-${app.version}',
                                  ),
                                  app: app,
                                  preferTvBanner: !widget.compactIcons,
                                  size: widget.compactIcons ? 62 : 72,
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
