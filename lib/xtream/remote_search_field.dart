import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV navigation is separate from text entry; arrows must never trap focus.
class RemoteSearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged, onSubmit;
  final VoidCallback onUp, onLeft, onRight;
  const RemoteSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
    required this.onUp,
    required this.onLeft,
    required this.onRight,
  });
  @override
  State<RemoteSearchField> createState() => _RemoteSearchFieldState();
}

class _RemoteSearchFieldState extends State<RemoteSearchField> {
  bool _editing = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant RemoteSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
  }

  void _focusChanged() {
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  void _edit() {
    setState(() => _editing = true);
    widget.focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing && widget.focusNode.hasFocus)
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _leave(VoidCallback action) {
    setState(() => _editing = false);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    action();
  }

  void _submit() => _leave(() => widget.onSubmit(widget.controller.text));
  @override
  void dispose() {
    widget.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowDown): _submit,
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _leave(widget.onUp),
      if (!_editing) ...{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): widget.onLeft,
        const SingleActivator(LogicalKeyboardKey.arrowRight): widget.onRight,
      },
      const SingleActivator(LogicalKeyboardKey.select): _edit,
      const SingleActivator(LogicalKeyboardKey.gameButtonA): _edit,
      const SingleActivator(LogicalKeyboardKey.enter): () =>
          _editing ? _submit() : _edit(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
          _editing ? _submit() : _edit(),
      if (_editing) ...{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _leave(widget.focusNode.requestFocus),
        const SingleActivator(LogicalKeyboardKey.goBack): () =>
            _leave(widget.focusNode.requestFocus),
        const SingleActivator(LogicalKeyboardKey.gameButtonB): () =>
            _leave(widget.focusNode.requestFocus),
      },
    },
    child: TextField(
      key: const ValueKey('xtream-search-input'),
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: !_editing,
      onTap: _edit,
      textInputAction: TextInputAction.search,
      onEditingComplete: () {},
      onSubmitted: (_) => _submit(),
      onChanged: widget.onChanged,
      decoration: const InputDecoration(
        labelText: 'بحث في المحتوى المتاح',
        prefixIcon: Icon(Icons.search),
        helperText: 'موافق للكتابة · ↓ للنتائج',
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
    ),
  );
}
