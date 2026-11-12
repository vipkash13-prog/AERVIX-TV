import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'playback.dart';
import 'xtream_service.dart';

class XtreamPlayerPage extends StatefulWidget {
  final XtreamService service;
  final List<MediaEntry> playlist;
  final int index;
  final MediaEntry? series;
  final List<MediaEntry> Function()? currentPlaylist;
  final MediaEngine? engine;
  const XtreamPlayerPage({
    super.key,
    required this.service,
    required this.playlist,
    this.index = 0,
    this.series,
    this.currentPlaylist,
    this.engine,
  });
  @override
  State<XtreamPlayerPage> createState() => _XtreamPlayerPageState();
}

class _XtreamPlayerPageState extends State<XtreamPlayerPage> {
  late final ChannelPlayback _session;
  Timer? _overlay;
  bool _show = true, _exiting = false;
  @override
  void initState() {
    super.initState();
    _session = ChannelPlayback(
      engine: widget.engine ?? VideoMediaEngine(),
      playlist: widget.playlist,
      index: widget.index,
      resolve: (media) => widget.service.stream(
        media,
        episode: widget.series != null,
        parent: widget.series,
      ),
    );
    _session.addListener(_channelChanged);
    _session.engine.addListener(_changed);
    widget.service.addListener(_catalogueChanged);
    _session.start();
    _showInfo();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  void _catalogueChanged() {
    if (widget.currentPlaylist != null) {
      _session.update(widget.currentPlaylist!());
    } else if (widget.series != null &&
        !widget.service.isAllowed(widget.series!)) {
      _session.update([]);
    } else if (widget.series == null &&
        _session.current != null &&
        !widget.service.isAllowed(_session.current!)) {
      _session.update([]);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _channelChanged() {
    _showInfo();
    _changed();
  }

  void _showInfo() {
    _overlay?.cancel();
    _show = true;
    _overlay = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    widget.service.removeListener(_catalogueChanged);
    _overlay?.cancel();
    _session.removeListener(_channelChanged);
    _session.engine.removeListener(_changed);
    _session.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  KeyEventResult _key(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if ([
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.gameButtonB,
    ].contains(key)) {
      if (event is KeyDownEvent && !_exiting) {
        _exiting = true;
        unawaited(_session.engine.stop());
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }
    if (_session.live &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      _session.zap(key == LogicalKeyboardKey.arrowUp ? 1 : -1);
      return KeyEventResult.handled;
    }
    if ([
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.gameButtonA,
      LogicalKeyboardKey.mediaPlayPause,
      LogicalKeyboardKey.space,
    ].contains(key)) {
      if (event is KeyDownEvent) {
        if (_session.engine.error != null) {
          _session.retry();
        } else {
          unawaited(_session.engine.togglePause());
        }
        _showInfo();
        _changed();
      }
      return KeyEventResult.handled;
    }
    if (!_session.live &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowLeft)) {
      unawaited(
        _session.engine.seekBy(
          Duration(seconds: key == LogicalKeyboardKey.arrowRight ? 10 : -10),
        ),
      );
      _showInfo();
      _changed();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showInfo();
      _changed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final current = _session.current;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_session.engine.stop());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Focus(
            autofocus: true,
            onKeyEvent: (_, event) => _key(event),
            child: GestureDetector(
              onTap: () {
                _showInfo();
                _changed();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _session.engine.picture(),
                  if (current != null && _session.engine.loading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD68A),
                      ),
                    ),
                  if (current == null || _session.engine.error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          current == null
                              ? 'المحتوى غير متاح أو تم حظره'
                              : _session.engine.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  if (_show && current != null)
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xDF0A0E14),
                          border: Border.all(color: const Color(0xFFFFD68A)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_session.live ? '${_session.number} · ' : ''}${current.name}',
                                key: const ValueKey('playing-channel'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _session.live
                                    ? '↑ القناة التالية    ↓ القناة السابقة    موافق إيقاف/تشغيل    رجوع للقائمة'
                                    : 'موافق إيقاف/تشغيل    ← → تقديم/ترجيع 10 ثوانٍ    رجوع للقائمة',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
