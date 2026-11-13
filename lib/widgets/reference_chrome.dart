import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const referenceGold = Color(0xFFFFD68A);

/// Measured in the attached 1280x720 reference; the entire scene scales uniformly.
abstract final class ReferenceLayout {
  static const Size canvas = Size(1280, 720);
  static const sidebar = Rect.fromLTWH(980, 115, 275, 366);
  static const weather = Rect.fromLTWH(378, 386, 288, 122);
  static const prayer = Rect.fromLTWH(40, 386, 322, 122);
  static const clock = Rect.fromLTWH(1045, 9, 210, 66);
  static const movies = Rect.fromLTWH(980, 116, 275, 72);
  static const series = Rect.fromLTWH(995, 195, 260, 64);
  static const live = Rect.fromLTWH(995, 268, 260, 64);
  static const sports = Rect.fromLTWH(995, 341, 260, 64);
  static const apps = Rect.fromLTWH(995, 414, 260, 64);
  static const sportsPanel = Rect.fromLTWH(680, 378, 303, 136);
  static const dock = Rect.fromLTWH(48, 548, 1184, 126);
  static const appSlots = Rect.fromLTWH(210, 555, 984, 110);
  static String wallpaper(double physicalWidth) => physicalWidth >= 3000
      ? 'assets/premium_home/makkah_jeddah_uhd.png'
      : 'assets/premium_home/makkah_jeddah_fhd.png';
}

KeyEventResult referenceDirections(
  KeyEvent event, {
  VoidCallback? left,
  VoidCallback? right,
  VoidCallback? up,
  VoidCallback? down,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent)
    return KeyEventResult.ignored;
  final action = switch (event.logicalKey) {
    LogicalKeyboardKey.arrowLeft => left,
    LogicalKeyboardKey.arrowRight => right,
    LogicalKeyboardKey.arrowUp => up,
    LogicalKeyboardKey.arrowDown => down,
    _ => null,
  };
  if (action == null) return KeyEventResult.ignored;
  action();
  return KeyEventResult.handled;
}

class ReferenceFocusable extends StatefulWidget {
  final FocusNode? focusNode;
  final bool autofocus;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final KeyEventResult Function(KeyEvent)? onKey;
  final ValueChanged<bool>? onFocusChanged;
  final Widget Function(BuildContext, bool) builder;
  const ReferenceFocusable({
    super.key,
    this.focusNode,
    this.autofocus = false,
    required this.label,
    required this.onPressed,
    required this.builder,
    this.onKey,
    this.onLongPress,
    this.onFocusChanged,
  });
  @override
  State<ReferenceFocusable> createState() => _ReferenceFocusableState();
}

class _ReferenceFocusableState extends State<ReferenceFocusable> {
  bool _focused = false, _pending = false, _held = false;
  Timer? _holdTimer;
  static const _activationKeys = [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.space,
  ];
  void _activate() {
    if (widget.onLongPress == null) {
      widget.onPressed();
      return;
    }
    if (_pending) return;
    _pending = true;
    _held = false;
    _holdTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _pending) {
        _held = true;
        widget.onLongPress!();
      }
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
            ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
            ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select, includeRepeats: false):
            ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA, includeRepeats: false):
            ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
            ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (!value) {
          _holdTimer?.cancel();
          _pending = false;
        }
        widget.onFocusChanged?.call(value);
      },
      child: Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: widget.builder(context, _focused),
        ),
      ),
    );
    result = Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyUpEvent &&
            _pending &&
            _activationKeys.contains(event.logicalKey)) {
          _holdTimer?.cancel();
          _pending = false;
          if (!_held) widget.onPressed();
          return KeyEventResult.handled;
        }
        if (event is KeyRepeatEvent &&
            const [
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.numpadEnter,
              LogicalKeyboardKey.select,
              LogicalKeyboardKey.gameButtonA,
              LogicalKeyboardKey.space,
            ].contains(event.logicalKey))
          return KeyEventResult.handled;
        return widget.onKey?.call(event) ?? KeyEventResult.ignored;
      },
      child: result,
    );
    return result;
  }
}

Path referenceFramePath(Size size, double radius, int skew) {
  final w = size.width, h = size.height;
  if (skew == 0)
    return Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
  final tl = skew < 0 ? 11.0 : 1.0, tr = skew > 0 ? 11.0 : 1.0;
  return Path()
    ..moveTo(radius, tl)
    ..lineTo(w - radius - 3, tr)
    ..quadraticBezierTo(w, tr, w - 1, radius + tr)
    ..lineTo(w - 4, h - radius)
    ..quadraticBezierTo(w - 5, h - 2, w - radius - 5, h - 2)
    ..lineTo(radius, h)
    ..quadraticBezierTo(0, h, 1, h - radius)
    ..lineTo(3, radius + tl)
    ..quadraticBezierTo(4, tl + 1, radius, tl)
    ..close();
}

class _ReferenceClip extends CustomClipper<Path> {
  final double radius;
  final int skew;
  const _ReferenceClip(this.radius, this.skew);
  @override
  Path getClip(Size size) => referenceFramePath(size, radius, skew);
  @override
  bool shouldReclip(covariant _ReferenceClip old) =>
      radius != old.radius || skew != old.skew;
}

/// Vector glass and metal remain sharp at UHD; no screenshot is used as UI.
class ReferenceGlass extends StatelessWidget {
  final Widget child;
  final bool focused;
  final bool active;
  final bool hero;
  final bool minimal;
  final double radius;
  final int skew;
  const ReferenceGlass({
    super.key,
    required this.child,
    this.focused = false,
    this.active = false,
    this.hero = false,
    this.minimal = false,
    this.radius = 22,
    this.skew = 0,
  });
  @override
  Widget build(BuildContext context) => minimal && !focused && !active
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(
            end: focused
                ? 1
                : active
                ? .64
                : 0,
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: ClipPath(clipper: _ReferenceClip(radius, skew), child: child),
          builder: (context, value, child) => CustomPaint(
            painter: _GlassPainter(radius, skew, value, hero, false),
            foregroundPainter: _GlassPainter(radius, skew, value, hero, true),
            child: child,
          ),
        );
}

class _GlassPainter extends CustomPainter {
  final double radius, glow;
  final int skew;
  final bool hero, foreground;
  const _GlassPainter(
    this.radius,
    this.skew,
    this.glow,
    this.hero,
    this.foreground,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final path = referenceFramePath(size, radius, skew);
    final bounds = Offset.zero & size;
    if (!foreground) {
      if (glow > .01)
        canvas.drawPath(
          path,
          Paint()
            ..color = referenceGold.withValues(alpha: .55 * glow)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                const Color(0xE7283445),
                const Color(0xF47B5928),
                glow,
              )!,
              const Color(0xDD040A12),
              Color.lerp(
                const Color(0xDF182334),
                const Color(0xED725326),
                glow,
              )!,
            ],
          ).createShader(bounds),
      );
      return;
    }
    canvas.save();
    canvas.clipPath(path);
    final gloss = Path()
      ..moveTo(size.width * .11, 0)
      ..lineTo(size.width * .62, 0)
      ..lineTo(size.width * .12, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: hero ? .025 : .012),
            Colors.transparent,
          ],
        ).createShader(bounds),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hero ? 1.8 + glow : 1 + glow * 1.5
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xE7F7FAFF), const Color(0xFFFFE6AA), glow)!,
            Color.lerp(const Color(0x595D6B7E), referenceGold, glow)!,
            hero || glow > .1
                ? const Color(0xFFFFDA8B)
                : const Color(0xC487929E),
          ],
          stops: const [0, .55, 1],
        ).createShader(bounds),
    );
    final top = Offset(size.width * .5, skew == 0 ? 1 : 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: top,
        width: size.width * .42,
        height: hero ? 7 : 3,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: hero ? 0.8 : 0.35),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(center: top, width: size.width * .42, height: 8),
            ),
    );
    if (hero) {
      canvas.drawLine(
        Offset(size.width * .08, size.height - 3),
        Offset(size.width * .92, size.height - 3),
        Paint()
          ..color = const Color(0xCCFFD895)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      final bottom = Offset(size.width * .5, size.height - 2);
      canvas.drawOval(
        Rect.fromCenter(center: bottom, width: size.width * .9, height: 7),
        Paint()
          ..shader =
              RadialGradient(
                colors: [const Color(0xDDFFD084), Colors.transparent],
              ).createShader(
                Rect.fromCenter(
                  center: bottom,
                  width: size.width * .9,
                  height: 10,
                ),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) =>
      glow != old.glow ||
      radius != old.radius ||
      skew != old.skew ||
      hero != old.hero ||
      foreground != old.foreground;
}

class ReferenceSidebarPainter extends CustomPainter {
  const ReferenceSidebarPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 214, size.height / 720);
    final outline = Path()
      ..moveTo(0, 0)
      ..lineTo(129, 0)
      ..cubicTo(183, 7, 210, 34, 211, 94)
      ..lineTo(212, 515)
      ..cubicTo(213, 575, 193, 595, 157, 622)
      ..lineTo(100, 679)
      ..quadraticBezierTo(83, 697, 78, 720)
      ..lineTo(0, 720)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF202733), Color(0xFA070B10), Color(0xEF111920)],
        ).createShader(const Rect.fromLTWH(0, 0, 214, 720)),
    );
    canvas.save();
    canvas.clipPath(outline);
    canvas.drawPath(
      Path()
        ..moveTo(36, 22)
        ..lineTo(170, 149)
        ..lineTo(77, 239)
        ..lineTo(16, 46)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x475C697B), Color(0x00000000)],
        ).createShader(const Rect.fromLTWH(10, 0, 180, 250)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 547)
        ..lineTo(92, 650)
        ..lineTo(172, 593)
        ..lineTo(120, 661)
        ..lineTo(48, 720)
        ..lineTo(0, 720)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x036C7A8B),
            Color(0xAE3D4858),
            Color(0xCCB5C0CE),
            Color(0xFF1A2433),
          ],
        ).createShader(const Rect.fromLTWH(0, 540, 175, 180)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 610)
        ..lineTo(66, 679)
        ..lineTo(30, 720)
        ..lineTo(0, 720)
        ..close(),
      Paint()..color = const Color(0xAA03070C),
    );
    canvas.restore();
    final edge = Path()
      ..moveTo(130, 0)
      ..cubicTo(184, 7, 210, 35, 211, 94)
      ..lineTo(212, 515)
      ..cubicTo(213, 575, 193, 595, 157, 622)
      ..lineTo(100, 679)
      ..quadraticBezierTo(83, 697, 78, 720);
    canvas.drawPath(
      edge,
      Paint()
        ..color = const Color(0xAAFFC66C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      edge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFD389),
            Color(0xFFF4FAFF),
            Color(0xFFE5BD74),
            Color(0xFFFCF8E5),
            Color(0xFFFFCB75),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 214, 720))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ReferenceSidebarPainter oldDelegate) => false;
}

class ReferencePlayGlyph extends StatelessWidget {
  const ReferencePlayGlyph({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.black.withValues(alpha: .25),
      border: Border.all(color: const Color(0xFFD6BB83), width: 1.4),
    ),
    child: const Icon(
      Icons.play_arrow_rounded,
      color: Color(0xFFECE9E0),
      size: 27,
    ),
  );
}
