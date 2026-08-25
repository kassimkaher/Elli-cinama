import 'package:flutter/widgets.dart';

/// Lightweight localization (Design §80/§81). Arabic-first; English LTR also
/// supported. No user-facing string is hardcoded in widgets — all go through
/// `context.tr(key)`. Direction follows the app locale (ar → RTL).
class AbkStrings {
  static const supported = [Locale('ar'), Locale('en')];

  static const Map<String, Map<String, String>> _m = {
    'appName': {'ar': 'ABK', 'en': 'ABK'},
    // nav
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'live': {'ar': 'القنوات', 'en': 'Live'},
    'movies': {'ar': 'أفلام', 'en': 'Movies'},
    'series': {'ar': 'مسلسلات', 'en': 'Series'},
    'more': {'ar': 'المزيد', 'en': 'More'},
    'search': {'ar': 'بحث', 'en': 'Search'},
    'favorites': {'ar': 'المفضلة', 'en': 'Favorites'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'account': {'ar': 'الحساب', 'en': 'Account'},
    // actions
    'play': {'ar': 'تشغيل', 'en': 'Play'},
    'details': {'ar': 'التفاصيل', 'en': 'Details'},
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'back': {'ar': 'رجوع', 'en': 'Back'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'ok': {'ar': 'موافق', 'en': 'OK'},
    'fullscreen': {'ar': 'ملء الشاشة', 'en': 'Fullscreen'},
    // launch
    'preparingLibrary': {'ar': 'جارٍ تحضير المكتبة…', 'en': 'Preparing your library…'},
    'configFallback': {'ar': 'إعداد احتياطي', 'en': 'Using saved setup'},
    'configFallbackBody': {'ar': 'تم المتابعة بإعدادات محفوظة.', 'en': 'Continued with saved configuration.'},
    'configFailed': {'ar': 'لا يمكن الوصول للخدمة', 'en': 'Service unavailable'},
    'configFailedBody': {'ar': 'تحقّق من الاتصال ثم أعد المحاولة.', 'en': 'Check your connection and try again.'},
    'savedContent': {'ar': 'المحتوى المحفوظ', 'en': 'Saved content'},
    // login
    'loginTitle': {'ar': 'تسجيل الدخول', 'en': 'Sign in'},
    'loginSubtitle': {'ar': 'أدخل بيانات حسابك للمتابعة.', 'en': 'Enter your account to continue.'},
    'username': {'ar': 'اسم المستخدم', 'en': 'Username'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'enterUsername': {'ar': 'أدخل اسم المستخدم', 'en': 'Enter username'},
    'enterPassword': {'ar': 'أدخل كلمة المرور', 'en': 'Enter password'},
    'show': {'ar': 'إظهار', 'en': 'Show'},
    'hide': {'ar': 'إخفاء', 'en': 'Hide'},
    'signIn': {'ar': 'دخول', 'en': 'Sign in'},
    'signingIn': {'ar': 'جارٍ الدخول', 'en': 'Signing in…'},
    'invalidCredentials': {'ar': 'اسم المستخدم أو كلمة المرور غير صحيحة.', 'en': 'Incorrect username or password.'},
    'connectionError': {'ar': 'تعذّر الاتصال بالخدمة. تحقّق من الشبكة.', 'en': 'Could not reach the service. Check your network.'},
    'pleaseSignIn': {'ar': 'الرجاء تسجيل الدخول مجددًا', 'en': 'Please sign in again'},
    'cooldown': {'ar': 'أعد المحاولة بعد', 'en': 'Try again in'},
    // home
    'featured': {'ar': 'مميز', 'en': 'Featured'},
    'continueWatching': {'ar': 'متابعة المشاهدة', 'en': 'Continue watching'},
    'myFavoriteChannels': {'ar': 'قنواتي المفضلة', 'en': 'My favorite channels'},
    'remaining': {'ar': 'باقي', 'en': 'left'},
    'sectionFailed': {'ar': 'تعذّر تحميل هذا القسم', 'en': 'Couldn\'t load this section'},
    'sectionFailedBody': {'ar': 'بقية الأقسام تعمل بشكل طبيعي.', 'en': 'The rest is working normally.'},
    // live
    'categories': {'ar': 'الفئات', 'en': 'Categories'},
    'channels': {'ar': 'القنوات', 'en': 'Channels'},
    'allChannels': {'ar': 'كل القنوات', 'en': 'All channels'},
    'searchChannels': {'ar': 'ابحث في القنوات', 'en': 'Search channels'},
    'preview': {'ar': 'معاينة', 'en': 'Preview'},
    'noLogo': {'ar': 'بدون شعار', 'en': 'No logo'},
    'liveBadge': {'ar': 'مباشر', 'en': 'LIVE'},
    'archive': {'ar': 'أرشيف', 'en': 'ARCHIVE'},
    'locked': {'ar': 'مقفلة', 'en': 'Locked'},
    'reconnecting': {'ar': 'إعادة الاتصال…', 'en': 'Reconnecting…'},
    'streamFailed': {'ar': 'تعذّر تشغيل البث', 'en': 'Playback failed'},
    'preparing': {'ar': 'جارٍ التحضير…', 'en': 'Preparing…'},
    // catalogue / search
    'searchEverything': {'ar': 'ابحث في كل المحتوى', 'en': 'Search everything'},
    'noResults': {'ar': 'لا توجد نتائج', 'en': 'No results'},
    'noResultsBody': {'ar': 'جرّب كلمات مختلفة.', 'en': 'Try different keywords.'},
    'searchIdle': {'ar': 'ابحث في القنوات والأفلام والمسلسلات', 'en': 'Search live, movies and series'},
    'sortBy': {'ar': 'ترتيب', 'en': 'Sort'},
    'sortName': {'ar': 'الاسم', 'en': 'Name'},
    'sortYear': {'ar': 'السنة', 'en': 'Year'},
    'sortRating': {'ar': 'التقييم', 'en': 'Rating'},
    'sortDefault': {'ar': 'الافتراضي', 'en': 'Default'},
    'seasons': {'ar': 'المواسم', 'en': 'Seasons'},
    'episodes': {'ar': 'الحلقات', 'en': 'Episodes'},
    'season': {'ar': 'موسم', 'en': 'Season'},
    'episode': {'ar': 'حلقة', 'en': 'Episode'},
    'watchTrailer': {'ar': 'الإعلان', 'en': 'Trailer'},
    // favorites
    'favoritesEmpty': {'ar': 'لا مفضلة بعد', 'en': 'No favorites yet'},
    'favoritesEmptyBody': {'ar': 'أضف قنوات وأفلامًا لتظهر هنا.', 'en': 'Add channels and titles to see them here.'},
    // settings
    'appearance': {'ar': 'المظهر', 'en': 'Appearance'},
    'language': {'ar': 'اللغة', 'en': 'Language'},
    'playback': {'ar': 'التشغيل', 'en': 'Playback'},
    'dataCache': {'ar': 'البيانات والتخزين', 'en': 'Data & cache'},
    'parentalLock': {'ar': 'القفل الأبوي', 'en': 'Parental lock'},
    'about': {'ar': 'حول', 'en': 'About'},
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Log out'},
    'system': {'ar': 'النظام', 'en': 'System'},
    'dark': {'ar': 'داكن', 'en': 'Dark'},
    'light': {'ar': 'فاتح', 'en': 'Light'},
    'arabic': {'ar': 'العربية', 'en': 'Arabic'},
    'english': {'ar': 'English', 'en': 'English'},
    'expires': {'ar': 'ينتهي في', 'en': 'Expires'},
    'clearCache': {'ar': 'مسح التخزين المؤقت', 'en': 'Clear cache'},
    'cacheCleared': {'ar': 'تم تحديث المحتوى', 'en': 'Content refreshed'},
    // dev/QA-only
    'qaAccount': {'ar': 'حساب الاختبار', 'en': 'QA account'},
    'qaFillHint': {'ar': 'اضغط لتعبئة بيانات الاختبار', 'en': 'Tap to fill test credentials'},
    // parental
    'enterPin': {'ar': 'أدخل رمز القفل', 'en': 'Enter PIN'},
    'setPin': {'ar': 'تعيين رمز القفل', 'en': 'Set PIN'},
    'changePin': {'ar': 'تغيير رمز القفل', 'en': 'Change PIN'},
    'removePin': {'ar': 'إزالة الرمز', 'en': 'Remove PIN'},
    'pinProtected': {'ar': 'المحتوى المقفل محمي برمز', 'en': 'Locked content is PIN-protected'},
    'pinNotSet': {'ar': 'اضغط لتعيين رمز', 'en': 'Tap to set a PIN'},
    'wrongPin': {'ar': 'رمز غير صحيح', 'en': 'Wrong PIN'},
    'lockedContent': {'ar': 'محتوى مقفل', 'en': 'Locked content'},
    'lockedContentBody': {'ar': 'يتطلب رمز القفل الأبوي.', 'en': 'Requires the parental PIN.'},
    'lockContent': {'ar': 'قفل', 'en': 'Lock'},
    'unlockContent': {'ar': 'إلغاء القفل', 'en': 'Unlock'},
    // states / errors
    'empty': {'ar': 'لا يوجد محتوى', 'en': 'Nothing here'},
    'somethingWrong': {'ar': 'حدث خطأ ما', 'en': 'Something went wrong'},
    'offline': {'ar': 'لا يوجد اتصال', 'en': 'You\'re offline'},
    'staleData': {'ar': 'محتوى محفوظ', 'en': 'Showing saved content'},
    'loading': {'ar': 'جارٍ التحميل…', 'en': 'Loading…'},
    'title': {'ar': 'العنوان', 'en': 'Title'},
  };

  static String get(String key, String lang) =>
      _m[key]?[lang] ?? _m[key]?['en'] ?? key;
}

extension AbkTr on BuildContext {
  String tr(String key) => AbkStrings.get(key, Localizations.localeOf(this).languageCode);
  String get lang => Localizations.localeOf(this).languageCode;
}
