import 'package:flutter/material.dart';
import 'reference_chrome.dart';

/// No blur/filter or continuous animation: cheap static glass for TV GPUs.
class PremiumGlass extends StatelessWidget {
  final Widget child;
  final bool focused;
  final double radius;
  final bool purple;
  const PremiumGlass({
    super.key,
    required this.child,
    this.focused = false,
    this.radius = 24,
    this.purple = false,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused ? referenceGold : const Color(0x668F929C),
        width: 1.5,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: focused
            ? const [Color(0xED13100D), Color(0xB7794B13), Color(0xF20C0B0D)]
            : purple
            ? const [Color(0xED090B15), Color(0xCD1B132A), Color(0xB82D1C37)]
            : const [Color(0xC5262B34), Color(0xCF0C0F14), Color(0xBD121318)],
      ),
      boxShadow: focused
          ? const [
              BoxShadow(
                color: Color(0x66EDB95C),
                blurRadius: 14,
                spreadRadius: 1,
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
