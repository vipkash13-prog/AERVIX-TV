import 'package:flutter/material.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';
import '../providers/dock_favourites.dart';
import 'dock_favourites_editor.dart';

Future<void> editDockApp(
  BuildContext context,
  App app,
  DockFavourites store,
  AppsService service,
) async {
  final isFavourite = store
      .visible(service.applications)
      .any((a) => a.packageName == app.packageName);
  final action = await showDialog<String>(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: SimpleDialog(
        title: Text('تعديل ${app.name}'),
        children: [
          for (final entry in {
            if (isFavourite) 'move': 'نقل التطبيق',
            if (!isFavourite) 'add': 'إضافة إلى المفضلة',
            'hide': 'إخفاء التطبيق',
            if (isFavourite) 'remove': 'إزالة من المفضلة',
            'manage': 'تعديل المفضلة وإضافة تطبيق',
            'uninstall': 'إلغاء التثبيت',
            'cancel': 'رجوع',
          }.entries)
            TextButton(
              autofocus: entry.key == (isFavourite ? 'move' : 'add'),
              onPressed: () => Navigator.pop(context, entry.key),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(entry.value),
              ),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null || action == 'cancel') return;
  try {
    final available = service.applications.toList();
    final selected = store.visible(available);
    if (action == 'add' && selected.length < DockFavourites.limit) {
      await store.save([
        ...selected.map((a) => a.packageName),
        app.packageName,
      ]);
    } else if (action == 'manage' || action == 'add') {
      await editDockFavourites(context, store, available);
    } else if (action == 'move') {
      final target = await showDialog<int>(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: SimpleDialog(
            title: const Text('نقل إلى الموضع'),
            children: [
              for (var i = 0; i < selected.length; i++)
                TextButton(
                  autofocus: selected[i].packageName == app.packageName,
                  onPressed: () => Navigator.pop(context, i),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${i + 1} · ${selected[i].name}'),
                  ),
                ),
            ],
          ),
        ),
      );
      final from = selected.indexWhere((a) => a.packageName == app.packageName);
      if (target != null && from >= 0) {
        selected.insert(target, selected.removeAt(from));
        await store.save(selected.map((a) => a.packageName).toList());
      }
    } else if (action == 'hide' || action == 'remove') {
      if (action == 'hide') await service.hideApplication(app);
      await store.save(
        selected
            .where((a) => a.packageName != app.packageName)
            .map((a) => a.packageName)
            .toList(),
      );
    } else if (action == 'uninstall') {
      // Android presents its own confirmation; never uninstall silently or
      // remove the favourite before the package removal event is received.
      await service.uninstallApp(app);
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تعديل التطبيق. حاول مجددًا.')),
      );
  }
}
