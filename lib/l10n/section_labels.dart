import 'package:flutter/widgets.dart';

/// Translate only built-in display names; never rename persisted user data.
String sectionLabel(BuildContext context, String name) {
  if (Localizations.localeOf(context).languageCode != 'ar') return name;
  return const {
        'All Apps': 'جميع التطبيقات',
        'Movies & Shows': 'الأفلام والمسلسلات',
        'Music': 'الموسيقى',
        'Games': 'الألعاب',
        'Entertainment': 'الترفيه',
        'Live TV': 'البث المباشر',
        'Sports': 'الرياضة',
        'News': 'الأخبار',
        'Tools': 'الأدوات',
        'Favorites': 'المفضلة',
        'Custom...': 'اسم مخصص…',
        'Last Used': 'آخر استخدام',
        'TV Apps': 'تطبيقات التلفاز',
        'Non-TV Apps': 'تطبيقات غير مخصصة للتلفاز',
      }[name] ??
      name;
}
