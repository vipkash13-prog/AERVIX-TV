import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'models.dart';

abstract class MediaEngine extends ChangeNotifier {
  bool get loading;
  bool get playing;
  String? get error;
  Widget picture();
  Future<void> open(Uri uri, {required bool live});
  Future<void> togglePause();
  Future<void> seekBy(Duration amount);
  Future<void> stop();
}

/// Only creation/disposal is queued; network initialization never blocks a zap.
class VideoMediaEngine extends MediaEngine {
  VideoPlayerController? _controller;
  Future<void> _queue = Future.value();
  int _generation = 0, _retryCount = 0, _failedGeneration = -1;
  Timer? _retryTimer;
  Uri? _uri;

  final _initTimeouts = <VideoPlayerController, Timer>{};
  void _cancelTimeouts() {
    for (final timer in _initTimeouts.values) {
      timer.cancel();
    }
    _initTimeouts.clear();
  }

  bool _closed = false, _loading = false;
  String? _error;
  @override
  bool get loading => _loading;
  @override
  bool get playing => _controller?.value.isPlaying ?? false;
  @override
  String? get error => _error;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  Future<void> open(Uri uri, {required bool live}) {
    _uri = uri;
    _retryCount = 0;
    return _openAttempt();
  }

  Future<void> _openAttempt() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final uri = _uri!;
    final generation = ++_generation;
    _cancelTimeouts();
    _loading = true;
    _error = null;
    _notify();
    // Pause immediately so the previous channel's audio cannot leak into the next.
    final previous = _controller;
    previous?.removeListener(_changed);
    if (previous != null) unawaited(previous.pause().catchError((Object _) {}));
    _queue = _queue.catchError((Object _) {}).then((_) async {
      if (_closed || generation != _generation) return;
      final old = _controller;
      _controller = null;
      await old?.dispose();
      if (_closed || generation != _generation) return;
      final next = VideoPlayerController.networkUrl(
        uri,
        formatHint: uri.path.toLowerCase().endsWith('.m3u8')
            ? VideoFormat.hls
            : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = next;
      next.addListener(_changed);
      unawaited(_initialize(next, generation));
    });
    _queue = _queue.catchError((Object _) {
      if (!_closed && generation == _generation) {
        _failed(generation);
      }
    });
    return _queue;
  }

  Future<void> _initialize(VideoPlayerController next, int generation) async {
    _initTimeouts[next] = Timer(const Duration(seconds: 18), () {
      if (!_closed && generation == _generation) {
        _failed(generation);
      }
    });
    try {
      await next.initialize();
      if (_closed || generation != _generation || _controller != next) return;
      await next.play();
      if (_closed || generation != _generation) return;
      _loading = false;
      _notify();
    } catch (_) {
      if (!_closed && generation == _generation) {
        _failed(generation);
      }
    } finally {
      _initTimeouts.remove(next)?.cancel();
    }
  }

  void _failed(int generation) {
    if (_closed || generation != _generation || _failedGeneration == generation)
      return;
    _failedGeneration = generation;
    _controller?.removeListener(_changed);
    _cancelTimeouts();
    if (_retryCount < 2) {
      _retryCount++;
      _loading = true;
      _error = null;
      final current = _controller;
      if (current != null) unawaited(current.pause().catchError((Object _) {}));
      _retryTimer = Timer(Duration(milliseconds: 800 * _retryCount), () {
        if (!_closed && generation == _generation) unawaited(_openAttempt());
      });
    } else {
      unawaited(stop());
      _error =
          'تعذر تشغيل المحتوى بعد إعادة المحاولة تلقائيًا. تحقق من الاتصال وصلاحية الاشتراك، ثم اضغط موافق للمحاولة مجددًا.';
    }
    _notify();
  }

  void _changed() {
    final value = _controller?.value;
    if (value == null || _closed) return;
    if (value.hasError) {
      _failed(_generation);
      return;
    }
    _notify();
  }

  @override
  Widget picture() {
    final current = _controller;
    if (_loading || current == null || !current.value.isInitialized)
      return const SizedBox.expand();
    return Center(
      child: AspectRatio(
        aspectRatio: current.value.aspectRatio > 0
            ? current.value.aspectRatio
            : 16 / 9,
        child: VideoPlayer(current),
      ),
    );
  }

  @override
  Future<void> togglePause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  @override
  Future<void> seekBy(Duration amount) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final position = (c.value.position.inMilliseconds + amount.inMilliseconds)
        .clamp(0, c.value.duration.inMilliseconds);
    await c.seekTo(Duration(milliseconds: position));
  }

  @override
  Future<void> stop() {
    ++_generation;
    _retryTimer?.cancel();
    _retryTimer = null;
    _cancelTimeouts();
    _loading = false;
    final previous = _controller;
    previous?.removeListener(_changed);
    if (previous != null) unawaited(previous.pause().catchError((Object _) {}));
    _queue = _queue
        .catchError((Object _) {})
        .then((_) async {
          final old = _controller;
          _controller = null;
          await old?.dispose();
        })
        .catchError((Object _) {});
    return _queue;
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(stop());
    super.dispose();
  }
}

class ChannelPlayback extends ChangeNotifier {
  final MediaEngine engine;
  final Uri Function(MediaEntry) resolve;
  List<MediaEntry> _playlist;
  int _index;
  Timer? _zap;
  bool _disposed = false;
  ChannelPlayback({
    required this.engine,
    required this.resolve,
    required List<MediaEntry> playlist,
    required int index,
  }) : _playlist = List.of(playlist),
       _index = index.clamp(0, playlist.isEmpty ? 0 : playlist.length - 1);
  MediaEntry? get current => _playlist.isEmpty ? null : _playlist[_index];
  int get number => _index + 1;
  bool get live => current?.kind == MediaKind.live;
  void start() {
    _open();
  }

  void _open() {
    final media = current;
    if (media == null || _disposed) return;
    try {
      unawaited(
        engine.open(resolve(media), live: media.kind == MediaKind.live),
      );
    } on XtreamFailure {
      unawaited(engine.stop());
    }
  }

  void zap(int delta) {
    if (!live || _playlist.isEmpty) return;
    final next = (_index + delta).clamp(0, _playlist.length - 1);
    if (next == _index) return;
    _index = next;
    notifyListeners();
    // Coalesce held D-pad events without fetching a catalogue or returning to lists.
    _zap?.cancel();
    unawaited(engine.stop());
    _zap = Timer(const Duration(milliseconds: 75), _open);
  }

  void retry() {
    _zap?.cancel();
    _open();
  }

  void update(List<MediaEntry> playlist) {
    final old = current?.id;
    _playlist = List.of(playlist);
    final preserved = _playlist.indexWhere((m) => m.id == old);
    final changed = preserved < 0;
    _index = changed
        ? _index.clamp(0, _playlist.isEmpty ? 0 : _playlist.length - 1)
        : preserved;
    if (changed) {
      _zap?.cancel();
      unawaited(engine.stop());
      _open();
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _zap?.cancel();
    engine.dispose();
    super.dispose();
  }
}
