import 'lang.dart';

/// Bilingual UI strings (English / Urdu). Plain language, short words.
class S {
  const S(this.lang);
  final AppLang lang;

  bool get isUrdu => lang == AppLang.ur;
  String _t(String en, String ur) => isUrdu ? ur : en;

  /// Picks the English or Urdu field of a model (`s.pick(type.nameEn, type.nameUr)`).
  String pick(String en, String? ur) => isUrdu && (ur ?? '').isNotEmpty ? ur! : en;

  // app
  String get orgName => _t('WASA Bhakkar', 'واسا بھکر');
  String get orgFull => _t('Water and Sanitation Agency, Bhakkar', 'واٹر اینڈ سینی ٹیشن ایجنسی، بھکر');
  String get officeAppTitle => _t('Vehicle Service Challan System', 'گاڑی سروس چالان سسٹم');
  String get driverAppTitle => _t('WASA Driver', 'واسا ڈرائیور');
  String get language => _t('اردو', 'English');

  // login
  String get username => _t('Username', 'یوزر نیم');
  String get password => _t('Password', 'پاس ورڈ');
  String get signIn => _t('Sign in', 'لاگ ان کریں');
  String get signOut => _t('Sign out', 'لاگ آؤٹ');
  String get signingIn => _t('Signing in…', 'لاگ ان ہو رہا ہے…');
  String get loginHint => _t('Use the username given by the WASA office.', 'واسا دفتر کا دیا ہوا یوزر نیم لکھیں۔');

  // states
  String get loading => _t('Loading…', 'لوڈ ہو رہا ہے…');
  String get retry => _t('Try again', 'دوبارہ کوشش کریں');
  String get nothingHere => _t('Nothing here yet.', 'ابھی کچھ نہیں ہے۔');
  String get somethingWrong => _t('Something went wrong.', 'کچھ غلط ہو گیا۔');
  String get noAccessTitle => _t('No access', 'رسائی نہیں');
  String get notConfiguredTitle => _t('Server not configured', 'سرور سیٹ نہیں ہے');
  String get notConfiguredBody => _t(
      'Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (see README: env.json).',
      'ایپ کو SUPABASE_URL اور SUPABASE_PUBLISHABLE_KEY کے ساتھ چلائیں (README دیکھیں)۔');
  String get useDriverApp =>
      _t('Drivers use the WASA Driver app on their phone.', 'ڈرائیور حضرات موبائل پر واسا ڈرائیور ایپ استعمال کریں۔');
  String get useOfficeApp =>
      _t('This app is for drivers only. Office staff use the office app.', 'یہ ایپ صرف ڈرائیوروں کے لیے ہے۔');
  String get comingSoon => _t('Coming soon', 'جلد آ رہا ہے');

  // office navigation
  String get dashboard => _t('Dashboard', 'ڈیش بورڈ');
  String get vehicleBoard => _t('Vehicle Board', 'گاڑیوں کا بورڈ');
  String get newChallan => _t('New Challan', 'نیا چالان');
  String get challans => _t('Challans', 'چالانز');
  String get reports => _t('Reports', 'رپورٹس');
  String get map => _t('Map', 'نقشہ');
  String get masters => _t('Masters', 'بنیادی ڈیٹا');
  String get auditLog => _t('Audit Log', 'آڈٹ لاگ');
  String get paymentSimulator => _t('Payment Simulator (DEMO)', 'ادائیگی سمیولیٹر (ڈیمو)');

  // driver
  String get todaysJobs => _t("Today's Jobs", 'آج کے کام');
  String get noJobs => _t('No jobs right now.', 'ابھی کوئی کام نہیں۔');
  String get start => _t('Start', 'شروع کریں');
  String get reached => _t('Reached', 'پہنچ گیا');
  String get done => _t('Done', 'کام مکمل');
  String get call => _t('Call', 'کال');
  String get navigate => _t('Navigate', 'راستہ');
  String get showQr => _t('Show QR', 'کیو آر دکھائیں');
  String get scanVerify => _t('Scan & Verify', 'اسکین اور تصدیق');
  String get shareChallan => _t('Share challan', 'چالان شیئر کریں');
  String get myVehicle => _t('My vehicle', 'میری گاڑی');
  String get noCashLine => _t('Payment ONLINE only. Do not pay cash to any staff.',
      'ادائیگی صرف آن لائن۔ کسی ملازم کو نقد رقم نہ دیں۔');
}
