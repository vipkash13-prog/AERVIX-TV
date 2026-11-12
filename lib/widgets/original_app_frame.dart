import 'package:flutter/material.dart';

/// A neutral frame around unmodified package artwork; no coloured foreground.
class OriginalAppFrame extends StatelessWidget {
  final Widget child;
  final bool focused;
  const OriginalAppFrame({
    super.key,
    required this.child,
    this.focused = false,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    decoration: BoxDecoration(
      color: focused ? const Color(0x38FFFFFF) : const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(15),
      boxShadow: focused
          ? const [BoxShadow(color: Color(0x33FFFFFF), blurRadius: 5)]
          : const [],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: focused ? const Color(0xFFF0F3FA) : const Color(0x557B8797),
        width: 2,
      ),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(13), child: child),
  );
}
