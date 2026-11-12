// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get aboutFlauncher => 'حول AERVIX TV';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get addSection => 'إضافة قسم';

  @override
  String get alphabetical => 'أبجديًا';

  @override
  String get appCardHighlightAnimation => 'حركة تمييز بطاقة التطبيق';

  @override
  String get showFocusBorders => 'إظهار حدود التحديد';

  @override
  String get focusBorderThickness => 'سُمك حدود التحديد';

  @override
  String get focusBorderThin => 'خفيف (1.0 dp)';

  @override
  String get focusBorderDefault => 'افتراضي (1.5 dp)';

  @override
  String get focusBorderMedium => 'متوسط (2.0 dp)';

  @override
  String get focusBorderBold => 'عريض (3.0 dp)';

  @override
  String get appInfo => 'معلومات التطبيق';

  @override
  String get appKeyClick => 'صوت الضغط على أزرار الريموت';

  @override
  String get appearanceSettings => 'المظهر';

  @override
  String get backgroundBlur => 'تمويه الخلفية';

  @override
  String get dockBlur => 'تمويه شريط التطبيقات';

  @override
  String get dockDarkBackground => 'خلفية داكنة لشريط التطبيقات';

  @override
  String get dockShadow => 'ظل شريط التطبيقات';

  @override
  String get applications => 'التطبيقات';

  @override
  String get autoHideAppBar => 'إخفاء شريط الحالة تلقائيًا';

  @override
  String get hideStatusBarInGrid => 'إخفاء شريط الحالة داخل شبكة التطبيقات';

  @override
  String get backButtonAction => 'وظيفة زر الرجوع';

  @override
  String get category => 'الفئة';

  @override
  String get categories => 'الفئات';

  @override
  String get columnCount => 'عدد الأعمدة';

  @override
  String get date => 'التاريخ';

  @override
  String get dateAndTimeFormat => 'تنسيق التاريخ والوقت';

  @override
  String get delete => 'حذف';

  @override
  String get dialogOptionBackButtonActionDoNothing => 'عدم تنفيذ أي إجراء';

  @override
  String get dialogOptionBackButtonActionShowScreensaver => 'عرض شاشة التوقف';

  @override
  String get dialogOptionBackButtonActionShowClock => 'عرض الساعة';

  @override
  String get dialogTextNoFileExplorer => 'ثبّت مدير ملفات لاختيار صورة.';

  @override
  String get dialogTitleBackButtonAction => 'اختر وظيفة زر الرجوع';

  @override
  String disambiguateCategoryTitle(String title) {
    return '$title (فئة)';
  }

  @override
  String formattedDate(String dateString) {
    return 'التاريخ المنسق: $dateString';
  }

  @override
  String formattedTime(String timeString) {
    return 'الوقت المنسق: $timeString';
  }

  @override
  String get gradient => 'تدرج لوني';

  @override
  String get favoriteApps => 'التطبيقات المفضلة';

  @override
  String get grid => 'شبكة';

  @override
  String get height => 'الارتفاع';

  @override
  String get hide => 'إخفاء';

  @override
  String get hiddenApplications => 'التطبيقات المخفية';

  @override
  String get launcherSections => 'الأقسام';

  @override
  String get layout => 'التخطيط';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get manual => 'يدويًا';

  @override
  String get modifySection => 'تعديل القسم';

  @override
  String get mustNotBeEmpty => 'يجب ألا يكون فارغًا';

  @override
  String get name => 'الاسم';

  @override
  String get newSection => 'قسم جديد';

  @override
  String get noDateFormatSpecified => 'لم يُحدّد تنسيق للتاريخ';

  @override
  String get noTimeFormatSpecified => 'لم يُحدّد تنسيق للوقت';

  @override
  String get allApplications => 'جميع التطبيقات';

  @override
  String get nonTvApplications => 'التطبيقات غير المخصصة للتلفاز';

  @override
  String get open => 'فتح';

  @override
  String get orSelectFormatSpecifiers => 'أو اختر عناصر التنسيق';

  @override
  String get picture => 'صورة';

  @override
  String removeFrom(String name) {
    return 'إزالة من $name';
  }

  @override
  String get renameCategory => 'إعادة تسمية الفئة';

  @override
  String get reorder => 'إعادة الترتيب';

  @override
  String get row => 'صف';

  @override
  String get rowHeight => 'ارتفاع الصف';

  @override
  String get save => 'حفظ';

  @override
  String get spacer => 'فاصل';

  @override
  String get spacerMaxHeightRequirement =>
      'يجب أن يكون أكبر من 0 وأقل من أو يساوي 500';

  @override
  String get statusBar => 'شريط الحالة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get show => 'إظهار';

  @override
  String get showCategoryTitles => 'إظهار أسماء الفئات';

  @override
  String get sort => 'الترتيب';

  @override
  String get systemSettings => 'إعدادات الجهاز';

  @override
  String get updateCheck => 'التحقق من التحديثات';

  @override
  String get updateNoUpdateTitle => 'لا توجد تحديثات';

  @override
  String updateNoUpdateBody(String currentVersion) {
    return 'أنت تستخدم أحدث إصدار ($currentVersion).';
  }

  @override
  String get updateAvailableTitle => 'يتوفر تحديث';

  @override
  String updateAvailableBody(String latestVersion, String currentVersion) {
    return 'يتوفر الإصدار $latestVersion (الإصدار الحالي: $currentVersion).';
  }

  @override
  String get updateChangelog => 'الجديد في هذا الإصدار';

  @override
  String get updateDownloadButton => 'تنزيل';

  @override
  String get updateReadyToInstallTitle => 'التحديث جاهز للتثبيت';

  @override
  String updateReadyToInstallBody(String latestVersion) {
    return 'اكتمل تنزيل الإصدار $latestVersion. هل تريد بدء التثبيت الآن؟';
  }

  @override
  String get updateInstallButton => 'تثبيت';

  @override
  String get updateInstallPermissionTitle => 'يلزم السماح بتثبيت التحديثات';

  @override
  String get updateInstallPermissionBody =>
      'اسمح لتطبيق AERVIX TV بتثبيت التطبيقات من هذا المصدر، ثم أعد محاولة التحديث.';

  @override
  String get updateOpenPermissionSettingsButton => 'فتح إعدادات الإذن';

  @override
  String get updateErrorGeneric => 'تعذر التحقق من التحديث. حاول مجددًا.';

  @override
  String textAboutDialog(String repoUrl) {
    return 'AERVIX TV واجهة مفتوحة المصدر لأجهزة Android TV، مبنية على FLauncher وArc Launcher.\n\nتطوير النسخة الأساسية: Meddouri Badis.\nالمصدر البرمجي: $repoUrl.';
  }

  @override
  String get textEmptyCategory => 'هذه الفئة فارغة.';

  @override
  String get time => 'الوقت';

  @override
  String get titleStatusBarSettingsPage => 'اختر ما يظهر في شريط الحالة';

  @override
  String get tvApplications => 'تطبيقات التلفاز';

  @override
  String get type => 'النوع';

  @override
  String get typeInTheDateFormat => 'أدخل تنسيق التاريخ';

  @override
  String get typeInTheHourFormat => 'أدخل تنسيق الوقت';

  @override
  String get uninstall => 'إلغاء التثبيت';

  @override
  String get wallpaper => 'الخلفية';

  @override
  String get withEllipsisAddTo => 'إضافة إلى…';

  @override
  String get timeBasedWallpaper => 'خلفية حسب الوقت';

  @override
  String get unsplashSlideshow => 'عرض صور Unsplash';

  @override
  String get unsplashEnable => 'إظهار صور Unsplash';

  @override
  String get unsplashAccessKey => 'مفتاح الوصول إلى Unsplash';

  @override
  String get unsplashAccessKeyHelp =>
      'أنشئ تطبيقًا مجانيًا في unsplash.com/developers، ثم ألصق مفتاح الوصول.';

  @override
  String get unsplashNotSet => 'غير محدد';

  @override
  String get unsplashInterval => 'تغيير الصورة كل';

  @override
  String unsplashIntervalMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get slideshowCategories => 'الفئات';

  @override
  String get slideshowDay => 'النهار (06:00–18:00)';

  @override
  String get slideshowNight => 'الليل (18:00–06:00)';

  @override
  String unsplashPhotoCredit(String author) {
    return 'الصورة: $author / Unsplash';
  }

  @override
  String get pickDayWallpaper => 'اختيار خلفية النهار';

  @override
  String get pickNightWallpaper => 'اختيار خلفية الليل';

  @override
  String get video => 'فيديو';

  @override
  String get pickDayVideoWallpaper => 'اختيار فيديو للنهار';

  @override
  String get pickNightVideoWallpaper => 'اختيار فيديو لليل';

  @override
  String get watchNextSectionTitle => 'متابعة المشاهدة';

  @override
  String get showWatchNextSection => 'إظهار قسم متابعة المشاهدة';

  @override
  String get watchNextPermissionTitle => 'يلزم إذن متابعة المشاهدة';

  @override
  String get watchNextPermissionBody =>
      'اسمح بالوصول إلى قوائم التلفاز لعرض العناصر التي تتابع مشاهدتها.';

  @override
  String get watchNextGrantPermission => 'منح الإذن';

  @override
  String get watchNextCheckPermission => 'التحقق مجددًا';

  @override
  String get interface => 'الواجهة';

  @override
  String get system => 'النظام';

  @override
  String get accentColor => 'لون التمييز';

  @override
  String get miscellaneous => 'خيارات إضافية';

  @override
  String get brightnessScheduler => 'جدولة السطوع';

  @override
  String get screensaverSettings => 'إعدادات شاشة التوقف';

  @override
  String get screensaverClockStyle => 'نمط ساعة شاشة التوقف';

  @override
  String get wifiUsagePeriod => 'فترة قياس استهلاك Wi-Fi';

  @override
  String get showAppNamesBelowIcons => 'إظهار أسماء التطبيقات أسفل الأيقونات';

  @override
  String get wifiUsage => 'استهلاك Wi-Fi';

  @override
  String get networkIndicator => 'مؤشر الشبكة';

  @override
  String get customName => 'اسم مخصص';

  @override
  String get lastUsed => 'آخر استخدام';

  @override
  String get daily => 'يوميًا';

  @override
  String get weekly => 'أسبوعيًا';

  @override
  String get monthly => 'شهريًا';

  @override
  String get grantPermission => 'منح الإذن';

  @override
  String get checkStatus => 'التحقق من الحالة';

  @override
  String get watchNextBigPictureMode => 'وضع العرض الواسع';

  @override
  String get watchNextBigPictureModeDescription =>
      'خلفية بعرض الشاشة مع زر لبدء المشاهدة';

  @override
  String get watchNextWatch => 'مشاهدة';

  @override
  String get watchNextResume => 'استئناف';

  @override
  String get watchNextRefresh => 'تحديث المحتوى';

  @override
  String get watchNextRefreshDescription =>
      'إعادة تحميل الاقتراحات من تطبيقات الوسائط';

  @override
  String get watchNextRefreshed => 'تم تحديث محتوى متابعة المشاهدة';

  @override
  String get watchNextFilterApps => 'تصفية التطبيقات';

  @override
  String get watchNextFilterAppsDescription =>
      'اختر التطبيقات التي يمكنها عرض عناصر متابعة المشاهدة';

  @override
  String get watchNextNoApps =>
      'لا توجد تطبيقات تقدم محتوى متابعة المشاهدة حاليًا';

  @override
  String get watchNextShowAllApps => 'إظهار جميع التطبيقات المثبتة';

  @override
  String get watchNextHideWithoutImages =>
      'إخفاء البرامج التي لا تحتوي على صورة';

  @override
  String get watchNextHideWithoutImagesDescription =>
      'إظهار البرامج التي توفر ملصقًا أو صورة خلفية فقط';

  @override
  String get watchNextMaxItems => 'الحد الأقصى للبرامج';

  @override
  String get watchNextMaxItemsDescription =>
      'تحديد عدد البرامج في قسم متابعة المشاهدة';

  @override
  String get watchNextMaxItemsUnlimited => 'بلا حد';

  @override
  String get redditWallpaper => 'خلفيات Reddit';

  @override
  String get redditWallpaperEnable => 'إظهار خلفيات Reddit';

  @override
  String get redditSubreddits => 'مجتمعات Reddit';

  @override
  String get redditSort => 'الترتيب حسب';

  @override
  String get redditSortHot => 'الرائج';

  @override
  String get redditSortTopDay => 'الأفضل اليوم';

  @override
  String get redditSortTopWeek => 'الأفضل هذا الأسبوع';

  @override
  String get redditSortTopMonth => 'الأفضل هذا الشهر';

  @override
  String get redditSortTopAll => 'الأفضل على الإطلاق';

  @override
  String get redditSortNew => 'الأحدث';

  @override
  String get redditInterval => 'تغيير الخلفية كل';

  @override
  String redditIntervalMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get redditInterval1Hour => 'ساعة واحدة';

  @override
  String redditIntervalHours(int hours) {
    return '$hours ساعة';
  }

  @override
  String get redditInterval1Day => 'يوم واحد';

  @override
  String redditIntervalDays(int days) {
    return '$days يوم';
  }

  @override
  String get redditClientId => 'معرّف عميل Reddit (اختياري)';

  @override
  String get redditClientIdHelp =>
      'اختياري: أنشئ تطبيقًا مثبتًا في reddit.com/prefs/apps، ثم ألصق معرّفه إذا كانت شبكتك تتطلبه.';

  @override
  String get redditChangeNow => 'تغيير الخلفية الآن';

  @override
  String get redditAddSubreddit => 'إضافة مجتمع مخصص';

  @override
  String get redditSubredditName => 'اسم المجتمع (دون r/)';

  @override
  String get redditSubredditAdded => 'تمت إضافة المجتمع';

  @override
  String get redditSubredditInvalid => 'أدخل اسم مجتمع صالحًا';

  @override
  String get redditWallpaperUpdated => 'تم تحديث الخلفية';

  @override
  String get redditWallpaperFailed =>
      'تعذر جلب الخلفية. إذا استمرت المشكلة، أضف معرّف عميل Reddit في الإعدادات.';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get addToCategory => 'إضافة إلى فئة';

  @override
  String get setCustomBanner => 'تعيين صورة مخصصة';

  @override
  String get clearCustomBanner => 'إزالة الصورة المخصصة';

  @override
  String customBannerSetFailed(String error) {
    return 'تعذر تعيين الصورة: $error';
  }

  @override
  String customBannerClearFailed(String error) {
    return 'تعذر إزالة الصورة: $error';
  }

  @override
  String get selectImage => 'اختيار صورة';

  @override
  String get selectVideo => 'اختيار فيديو';

  @override
  String mediaItemCount(int count) {
    return '$count عنصر';
  }

  @override
  String get noImagesFound => 'لا توجد صور على الجهاز';

  @override
  String get noVideosFound => 'لا توجد مقاطع فيديو على الجهاز';

  @override
  String get mediaNavigationHint => 'أسهم الريموت: تنقل • رجوع: إلغاء';

  @override
  String get mediaSelectionHint =>
      'أسهم الريموت: تنقل • موافق: تعيين الخلفية • رجوع: إلغاء';

  @override
  String get mediaPermissionRequired => 'يلزم إذن الوصول إلى الوسائط';

  @override
  String get mediaPermissionHelp => 'امنح الإذن لاستعراض الصور ومقاطع الفيديو';

  @override
  String get preview => 'معاينة';

  @override
  String get colorPurple => 'بنفسجي';

  @override
  String get colorTeal => 'أخضر مزرق';

  @override
  String get colorBlue => 'أزرق';

  @override
  String get colorOrange => 'برتقالي';

  @override
  String get colorPink => 'وردي';

  @override
  String get colorGreen => 'أخضر';

  @override
  String get colorWhite => 'أبيض';

  @override
  String get colorYellow => 'أصفر';

  @override
  String get colorRed => 'أحمر';

  @override
  String get colorCyan => 'سماوي';

  @override
  String get colorIndigo => 'نيلي';

  @override
  String get colorLime => 'ليموني';

  @override
  String get colorAmber => 'كهرماني';

  @override
  String get colorRose => 'وردي داكن';

  @override
  String get colorIceBlue => 'أزرق جليدي';

  @override
  String get clockStyleMinimal => 'بسيط';

  @override
  String get clockStyleMinimalDescription => 'خط رفيع وأنيق (افتراضي)';

  @override
  String get clockStyleBold => 'عريض';

  @override
  String get clockStyleBoldDescription => 'خط سميك واضح من بعيد';

  @override
  String get clockStyleRetro => 'كلاسيكي رقمي';

  @override
  String get clockStyleRetroDescription =>
      'خط ثابت العرض بطابع الأجهزة القديمة';

  @override
  String get clockStyleElegant => 'أنيق';

  @override
  String get clockStyleElegantDescription => 'خط كلاسيكي بتفاصيل زخرفية';

  @override
  String get clockStyleNeon => 'نيون';

  @override
  String get clockStyleNeonDescription => 'خط فائق النحافة مع توهج';

  @override
  String get clockStylePixel => 'بكسل';

  @override
  String get clockStylePixelDescription => 'خط عريض بطابع ألعاب الأركيد';

  @override
  String get clockStyleDigital => 'رقمي';

  @override
  String get clockStyleDigitalDescription => 'عرض رقمي بخط ثابت العرض';

  @override
  String get brightnessPermissionRequired => 'يلزم منح إذن';

  @override
  String get brightnessPermissionHelp =>
      'للتحكم بالسطوع على هذا الجهاز، امنح الإذن باستخدام ADB:';

  @override
  String get brightnessExperimentalNotice =>
      'ميزة تجريبية: لم تُختبر على جميع الأجهزة وقد تتغير بناءً على ملاحظات المستخدمين.';

  @override
  String get brightnessDeviceSupportNote =>
      'ملاحظة: قد لا تدعم بعض أجهزة Android TV التحكم بسطوع التطبيق.';

  @override
  String get enableBrightnessScheduler => 'تفعيل الجدولة';

  @override
  String currentBrightnessSlot(String slot) {
    return 'الفترة الحالية: $slot';
  }

  @override
  String get brightnessSlotMorning => '06:00–09:00 صباحًا';

  @override
  String get brightnessSlotDay => '09:00 صباحًا–03:00 عصرًا';

  @override
  String get brightnessSlotAfternoon => '03:00–06:00 مساءً';

  @override
  String get brightnessSlotEvening => '06:00–10:00 مساءً';

  @override
  String get brightnessSlotNight => '10:00 مساءً–06:00 صباحًا';

  @override
  String get noApplicationsFound => 'لا توجد تطبيقات';

  @override
  String get invalidDateTimeFormat => 'صيغة غير صالحة';

  @override
  String get selectFormatsBelow => 'اختر صيغة من الخيارات أدناه';

  @override
  String get selectSectionName => 'اختر اسمًا للقسم';
}
