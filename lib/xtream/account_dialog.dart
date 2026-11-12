import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _nodes = [
    FocusNode(debugLabel: 'xtream-host'),
    FocusNode(debugLabel: 'xtream-user'),
    FocusNode(debugLabel: 'xtream-password'),
    FocusNode(debugLabel: 'xtream-save'),
    FocusNode(debugLabel: 'xtream-cancel'),
  ];
  int? _editing;
  bool _busy = false;

  void _move(int index) {
    if (_busy) return;
    setState(() => _editing = null);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    final node = _nodes[index.clamp(0, 4)];
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = node.context;
      if (mounted && fieldContext != null)
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 100),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
    });
  }

  void _edit(int index) {
    if (_busy) return;
    setState(() => _editing = index);
    _nodes[index].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_busy && _editing == index && _nodes[index].hasFocus) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
    });
  }

  Widget _remote(int index, Widget child, {bool field = false}) =>
      FocusTraversalOrder(
        order: NumericFocusOrder(index.toDouble()),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _move(index + 1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _move(index - 1),
            if (field) ...{
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  _edit(index),
              const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                  _edit(index),
              const SingleActivator(LogicalKeyboardKey.select): () =>
                  _edit(index),
              const SingleActivator(LogicalKeyboardKey.gameButtonA): () =>
                  _edit(index),
            } else ...{
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _move(3),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _move(4),
              const SingleActivator(LogicalKeyboardKey.enter): () =>
                  index == 3 ? _save() : Navigator.pop(context, false),
              const SingleActivator(LogicalKeyboardKey.select): () =>
                  index == 3 ? _save() : Navigator.pop(context, false),
              const SingleActivator(LogicalKeyboardKey.gameButtonA): () =>
                  index == 3 ? _save() : Navigator.pop(context, false),
            },
          },
          child: child,
        ),
      );
  String? _error;
  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _host.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _editing = null;
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
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _nodes[3].requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '↑ ↓ للتنقل بين الحقول · موافق للكتابة',
                      style: TextStyle(fontSize: 13, color: Colors.amber),
                    ),
                  ),
                  _remote(
                    0,
                    TextField(
                      key: const ValueKey('xtream-host-field'),
                      focusNode: _nodes[0],
                      readOnly: _editing != 0,
                      onTap: () => _edit(0),
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () {},
                      onSubmitted: (_) => _edit(1),
                      controller: _host,
                      autofocus: true,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFFFD68A),
                            width: 3,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFFFD68A)),
                        labelText: 'الهوست أو رابط الاشتراك',
                        hintText: 'https://host:port',
                      ),
                    ),
                    field: true,
                  ),
                  _remote(
                    1,
                    TextField(
                      key: const ValueKey('xtream-user-field'),
                      focusNode: _nodes[1],
                      readOnly: _editing != 1,
                      onTap: () => _edit(1),
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () {},
                      onSubmitted: (_) => _edit(2),
                      controller: _user,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFFFD68A),
                            width: 3,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFFFD68A)),
                        labelText: 'اسم المستخدم',
                      ),
                    ),
                    field: true,
                  ),
                  _remote(
                    2,
                    TextField(
                      key: const ValueKey('xtream-password-field'),
                      focusNode: _nodes[2],
                      readOnly: _editing != 2,
                      onTap: () => _edit(2),
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () {},
                      onSubmitted: (_) => _move(3),
                      controller: _password,
                      enabled: !_busy,
                      textDirection: TextDirection.ltr,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFFFD68A),
                            width: 3,
                          ),
                        ),
                        floatingLabelStyle: TextStyle(color: Color(0xFFFFD68A)),
                        labelText: 'كلمة المرور',
                      ),
                    ),
                    field: true,
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
            _remote(
              4,
              TextButton(
                focusNode: _nodes[4],
                style: TextButton.styleFrom(
                  overlayColor: const Color(0xFFFFD68A),
                ),
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
            ),
            _remote(
              3,
              TextButton(
                focusNode: _nodes[3],
                style: TextButton.styleFrom(
                  overlayColor: const Color(0xFFFFD68A),
                ),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'جارٍ التحقق…' : 'تحقق وحفظ'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
