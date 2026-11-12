import 'package:flutter/material.dart';
import '../models/app.dart';
import '../providers/dock_favourites.dart';

Future<void> editDockFavourites(
  BuildContext context,
  DockFavourites store,
  List<App> available,
) => showDialog<void>(
  context: context,
  builder: (_) => _Editor(store: store, available: available),
);

class _Editor extends StatefulWidget {
  final DockFavourites store;
  final List<App> available;
  const _Editor({required this.store, required this.available});
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final List<App> _available = widget.available
      .where((a) => !a.hidden && a.packageName != 'com.omeda.arc')
      .toList();
  late List<App> _selected = widget.store.visible(_available);
  bool _saving = false;
  String? _error;
  Future<void> _add() async {
    final remaining = _available
        .where((a) => !_selected.any((s) => s.packageName == a.packageName))
        .toList();
    final added = await showDialog<App>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تطبيق للمفضلة'),
        content: SizedBox(
          width: 480,
          height: 330,
          child: remaining.isEmpty
              ? const Center(child: Text('لا توجد تطبيقات أخرى'))
              : ListView.builder(
                  itemCount: remaining.length,
                  itemBuilder: (_, i) => ListTile(
                    autofocus: i == 0,
                    title: Text(remaining[i].name),
                    onTap: () => Navigator.pop(context, remaining[i]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
    if (added != null && mounted) setState(() => _selected.add(added));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(_selected.map((a) => a.packageName).toList());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ المفضلة. حاول مجددًا.';
        });
    }
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _selected.length) return;
    setState(() {
      final app = _selected.removeAt(index);
      _selected.insert(target, app);
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text('تعديل التطبيقات المفضلة (${_selected.length}/7)'),
      content: SizedBox(
        width: 650,
        height: 390,
        child: Column(
          children: [
            const Text(
              'أضف أو أزل تطبيقًا من الشريط، واستخدم الأسهم لتغيير ترتيبه. تُحفظ المفضلة عند الضغط على حفظ.',
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selected.length,
                itemBuilder: (context, index) {
                  final app = _selected[index];
                  return ListTile(
                    key: ValueKey('favourite-${app.packageName}'),
                    title: Text('${index + 1} · ${app.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تحريك للأعلى',
                          onPressed: _saving || index == 0
                              ? null
                              : () => _move(index, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'تحريك للأسفل',
                          onPressed: _saving || index == _selected.length - 1
                              ? null
                              : () => _move(index, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'إزالة من المفضلة',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _selected.removeAt(index)),
                          icon: const Icon(Icons.star_border),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.amber)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() => _selected = _available.take(7).toList()),
          child: const Text('استعادة الافتراضي'),
        ),
        TextButton(
          onPressed: _saving || _selected.length >= 7 ? null : _add,
          child: const Text('إضافة تطبيق'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          autofocus: true,
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    ),
  );
}
