import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const aervixGold = Color(0xFFFFD47D);

class GoldFocusTile extends StatefulWidget {
  final Widget child;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;
  final bool showLabel;
  final bool wide;
  const GoldFocusTile({
    super.key,
    required this.child,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.showLabel = true,
    this.wide = false,
  });
  @override
  State<GoldFocusTile> createState() => _GoldFocusTileState();
}

class _GoldFocusTileState extends State<GoldFocusTile> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: widget.autofocus,
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    },
    mouseCursor: SystemMouseCursors.click,
    onFocusChange: (focused) {
      setState(() => _focused = focused);
      if (focused)
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 180),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onPressed();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xD33C2B10) : const Color(0xBE0B0D10),
            borderRadius: BorderRadius.circular(24),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0xAAFFBC43),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
            image: DecorationImage(
              image: ExactAssetImage(
                widget.showLabel
                    ? 'assets/cards/card_${widget.wide ? 'category' : 'app'}_${_focused ? 'focused' : 'normal'}.png'
                    : 'assets/topbar/top_button_frame${_focused ? '_focused' : ''}.png',
                scale: 4,
              ),
              fit: BoxFit.fill,
              centerSlice: widget.showLabel
                  ? widget.wide
                        ? const Rect.fromLTRB(27.5, 21.25, 92.5, 53.75)
                        : const Rect.fromLTRB(22.5, 22.5, 57.5, 57.5)
                  : const Rect.fromLTRB(22.5, 22.5, 41.5, 41.5),
              opacity: .65,
              filterQuality: FilterQuality.low,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: widget.child),
              if (widget.showLabel) const SizedBox(height: 6),
              if (widget.showLabel)
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
