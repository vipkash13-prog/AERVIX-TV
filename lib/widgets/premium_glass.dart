import 'package:flutter/material.dart';
import 'reference_chrome.dart';

/// No blur/filter or continuous animation: cheap static glass for TV GPUs.
class PremiumGlass extends StatelessWidget {
  final Widget child;
  final bool focused;
  final double radius;
  final bool purple, accent;
  const PremiumGlass({
    super.key,
    required this.child,
    this.focused = false,
    this.radius = 24,
    this.purple = false,
    this.accent = false,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused
            ? referenceGold
            : accent
            ? const Color(0xBBD9B270)
            : const Color(0x668F929C),
        width: 1.5,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: focused
            ? const [
                Color(0xFFF3CD7B),
                Color(0xDD9A620F),
                Color(0xEF211A0D),
                Color(0xED382A14),
                Color(0xEBD6B36B),
              ]
            : purple
            ? const [Color(0xED090B15), Color(0xCD1B132A), Color(0xB82D1C37)]
            : const [Color(0xC5262B34), Color(0xCF0C0F14), Color(0xBD121318)],
      ),
      boxShadow: focused
          ? const [
              BoxShadow(
                color: Color(0xBBEDB95C),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ]
          : const [],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 1),
      child: child,
    ),
  );
}
