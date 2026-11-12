import 'package:flutter/material.dart';
import 'models.dart';
import 'xtream_service.dart';

Future<bool> showXtreamAccount(BuildContext context, XtreamService service) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _AccountDialog(service: service),
    ).then((v) => v ?? false);

class _AccountDialog extends StatefulWidget {
  final XtreamService service;
  const _AccountDialog({required this.service});
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _host = TextEditingController(text: widget.service.host ?? '');
  final _user = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _host.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.save(_host.text, _user.text, _password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is XtreamFailure
              ? error.message
              : 'تعذر حفظ الاشتراك',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اشتراك Xtream Codes'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'أدخل بيانات اشتراكك على الجهاز. تُحفظ بأمان وتُستخدم تلقائيًا في الأقسام الحالية. يمكنك لصق رابط get.php كاملًا بدل الحقول المنفصلة.',
                ),
                TextField(
                  controller: _host,
                  autofocus: true,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'الهوست أو رابط الاشتراك',
                    hintText: 'https://host:port',
                  ),
                ),
                TextField(
                  controller: _user,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                ),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'جارٍ التحقق…' : 'تحقق وحفظ'),
          ),
        ],
      ),
    ),
  );
}
