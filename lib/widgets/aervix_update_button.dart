import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/update_service.dart';
import 'gold_focus_tile.dart';

/// Checks in the background; downloading and installation require user action.
class AervixUpdateButton extends StatefulWidget {
  final UpdateService? service;
  final bool automaticallyCheck;
  const AervixUpdateButton({
    super.key,
    this.service,
    this.automaticallyCheck = true,
  });
  @override
  State<AervixUpdateButton> createState() => _AervixUpdateButtonState();
}

class _AervixUpdateButtonState extends State<AervixUpdateButton>
    with WidgetsBindingObserver {
  late final UpdateService _service;
  Timer? _timer;
  DateTime? _lastCheck;
  UpdateResult? _update;
  DownloadedApk? _downloaded;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? UpdateService();
    WidgetsBinding.instance.addObserver(this);
    if (widget.automaticallyCheck) {
      _check();
      _timer = Timer.periodic(const Duration(hours: 6), (_) => _check());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.automaticallyCheck &&
        state == AppLifecycleState.resumed &&
        (_lastCheck == null ||
            DateTime.now().difference(_lastCheck!) > const Duration(hours: 6)))
      _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool manual = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final update = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _update = update;
        _lastCheck = DateTime.now();
      });
      if (manual && !update.updateAvailable)
        _message('أنت تستخدم أحدث إصدار: ${update.currentVersion}');
    } catch (_) {
      if (manual && mounted)
        _message('تعذر فحص التحديث. تحقق من الاتصال وحاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String accept) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 280),
              child: SingleChildScrollView(child: Text(body)),
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('لاحقًا'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(accept),
              ),
            ],
          ),
        ),
      ) ??
      false;

  Future<void> _activate() async {
    if (_busy) return;
    if (_update == null || !_update!.updateAvailable)
      await _check(manual: true);
    if (!mounted || _update?.updateAvailable != true) return;
    if (_downloaded == null) {
      final update = _update!;
      final accepted = await _confirm(
        'تحديث AERVIX TV',
        'يتوفر الإصدار ${update.latestVersion}. ستبقى إعداداتك وتطبيقاتك محفوظة.\n\n${update.releaseNotes ?? ''}',
        'تنزيل التحديث',
      );
      if (!accepted || !mounted) return;
      setState(() => _busy = true);
      try {
        _downloaded = await _service.downloadApk(update);
      } catch (_) {
        if (mounted) _message('تعذر تنزيل التحديث. حاول مجددًا.');
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    final accepted = await _confirm(
      'تثبيت التحديث',
      'سيتم التحقق من اسم الحزمة والتوقيع ورقم الإصدار، ثم يفتح مثبت Android لطلب موافقتك. لا تحذف النسخة الحالية.',
      'متابعة التثبيت',
    );
    if (!accepted || !mounted) return;
    try {
      final opened = await _service.installApk(_downloaded!.path);
      if (!opened && mounted) {
        final allow = await _confirm(
          'السماح بتحديث التطبيق',
          'اسمح لـ AERVIX TV بتثبيت التحديثات في إعدادات Android، ثم ارجع واضغط زر التحديث للمتابعة.',
          'فتح الإعدادات',
        );
        if (allow) await _service.requestInstallUnknownAppsPermission();
      }
    } catch (_) {
      if (mounted)
        _message(
          'تعذر تثبيت الملف؛ يجب أن يطابق توقيع التطبيق وحزمته وأن يكون إصدارًا أحدث.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => GoldFocusTile(
    label: _busy
        ? 'جارٍ فحص أو تنزيل التحديث'
        : _update?.updateAvailable == true
        ? 'تحديث متاح'
        : 'تحديث التطبيق',
    showLabel: false,
    onPressed: _activate,
    child: _busy
        ? const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(strokeWidth: 2, color: aervixGold),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.system_update_alt, size: 30),
              if (_update?.updateAvailable == true)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(Icons.circle, size: 10, color: aervixGold),
                ),
            ],
          ),
  );
}
