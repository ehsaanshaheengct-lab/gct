import 'package:wasa_core/wasa_core.dart';

import 'lang.dart';

/// Bilingual UI strings (English / Urdu). Plain language, short words.
class S {
  const S(this.lang);
  final AppLang lang;

  bool get isUrdu => lang == AppLang.ur;
  String _t(String en, String ur) => isUrdu ? ur : en;

  /// Urdu text inside an English line: isolated so its brackets render the right way round.
  static String ur(String text) => '\u2067$text\u2069';

  /// Latin text inside an Urdu line ("6,000 litres"): isolated so it keeps its left-to-right order.
  static String ltr(String text) => '\u2066$text\u2069';

  /// Isolates [text] in its own direction when it has no Urdu letters (safe in both languages).
  static String auto(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? text : ltr(text);

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

  /// `PKR 2,000 / trip` (English) or `PKR 2,000 فی چکر` (Urdu).
  String rateText(double rate, PricingUnit unit) => isUrdu
      ? '${Fmt.pkr(rate)} ${unit.ur}'
      : '${Fmt.pkr(rate)} / ${unit.en.replaceFirst('per ', '')}';

  // common actions
  String get save => _t('Save', 'محفوظ کریں');
  String get cancel => _t('Cancel', 'منسوخ');
  String get add => _t('Add', 'شامل کریں');
  String get edit => _t('Edit', 'تبدیل کریں');
  String get delete => _t('Delete', 'حذف کریں');
  String get close => _t('Close', 'بند کریں');
  String get refresh => _t('Refresh', 'تازہ کریں');
  String get saved => _t('Saved.', 'محفوظ ہو گیا۔');
  String get all => _t('All', 'سب');
  String get active => _t('Active', 'فعال');
  String get inactive => _t('Inactive', 'غیر فعال');
  String get readOnly => _t('Read-only', 'صرف دیکھنے کے لیے');
  String get search => _t('Search', 'تلاش');

  // vehicles
  String get noDriver => _t('No driver set', 'ڈرائیور مقرر نہیں');
  String get noVehicles => _t('No vehicles match these filters.', 'ان فلٹرز کے مطابق کوئی گاڑی نہیں۔');
  String get vehicleType => _t('Vehicle type', 'گاڑی کی قسم');
  String get allTypes => _t('All types', 'تمام اقسام');
  String get status => _t('Status', 'حالت');
  String get regNo => _t('Registration no.', 'رجسٹریشن نمبر');
  String get makeModel => _t('Make / model', 'میک / ماڈل');
  String get year => _t('Year', 'سال');
  String get capacity => _t('Capacity', 'گنجائش');
  String get colour => _t('Colour', 'رنگ');
  String get defaultDriver => _t('Default driver', 'مقررہ ڈرائیور');
  String get trackerId => _t('Tracker device ID', 'ٹریکر ڈیوائس آئی ڈی');
  String get notes => _t('Notes', 'نوٹس');
  String get changeStatus => _t('Change status', 'حالت تبدیل کریں');
  String get reason => _t('Reason', 'وجہ');
  String get expectedBack => _t('Expected back', 'واپسی کی متوقع تاریخ');
  String get onJobAuto =>
      _t('On Job is set automatically when a challan is assigned.', 'چالان تفویض ہونے پر "کام پر" خود بخود لگ جاتا ہے۔');
  String get photos => _t('Photos', 'تصاویر');
  String get uploadPhoto => _t('Upload photo', 'تصویر اپ لوڈ کریں');
  String get mainPhoto => _t('Main photo', 'مرکزی تصویر');
  String get dragToReorder => _t('Drag to reorder. The first photo is the main one.', 'ترتیب کے لیے کھینچیں۔ پہلی تصویر مرکزی ہے۔');
  String get noPhotoYet => _t('No photo yet: the drawing is shown.', 'ابھی تصویر نہیں: خاکہ دکھایا جا رہا ہے۔');
  String get info => _t('Details', 'تفصیل');
  String get history => _t('History', 'ریکارڈ');
  String get maintenance => _t('Maintenance', 'مرمت');
  String get trips => _t('Trips done', 'مکمل چکر');
  String get amountGenerated => _t('Amount generated', 'کل رقم');
  String get amountPaid => _t('Amount paid', 'ادا شدہ رقم');
  String get lastTrip => _t('Last trip', 'آخری چکر');
  String get daysInMaintenance => _t('Days in maintenance', 'مرمت کے دن');
  String get fuelKmLater =>
      _t('Fuel and km will come from the GPS tracker (coming soon).', 'ایندھن اور کلومیٹر جی پی ایس ٹریکر سے آئیں گے (جلد)۔');
  String get addMaintenance => _t('Add maintenance entry', 'مرمت کا اندراج کریں');
  String get description => _t('Description', 'تفصیل');
  String get cost => _t('Cost (PKR)', 'لاگت (روپے)');
  String get from => _t('From', 'سے');
  String get to => _t('To', 'تک');
  String get ongoing => _t('ongoing', 'جاری');
  String get noHistory => _t('No challans for this vehicle yet.', 'اس گاڑی کا ابھی کوئی چالان نہیں۔');

  // masters
  String get vehicleTypes => _t('Vehicle Types', 'گاڑیوں کی اقسام');
  String get vehicles => _t('Vehicles', 'گاڑیاں');
  String get drivers => _t('Drivers', 'ڈرائیور');
  String get areas => _t('Areas', 'علاقے');
  String get tariff => _t('Tariff', 'نرخ نامہ');
  String get nameEn => _t('Name (English)', 'نام (انگریزی)');
  String get nameUr => _t('Name (Urdu)', 'نام (اردو)');
  String get category => _t('Category', 'زمرہ');
  String get pricingUnit => _t('Pricing unit', 'قیمت کی اکائی');
  String get paymentPolicy => _t('Payment policy', 'ادائیگی کی پالیسی');
  String get picture => _t('Picture', 'تصویر');
  String get sortOrder => _t('Order', 'ترتیب');
  String get phone => _t('Phone', 'فون');
  String get cnic => _t('CNIC', 'شناختی کارڈ');
  String get licence => _t('Licence no.', 'لائسنس نمبر');
  String get appLogin => _t('App login', 'ایپ لاگ ان');
  String get rate => _t('Rate (PKR)', 'نرخ (روپے)');
  String get effectiveFrom => _t('Effective from', 'نافذ از');
  String get placeholderRate => _t('placeholder', 'عارضی');
  String get tariffHelp => _t('Click a rate to change it. Old rates are kept in the history; existing challans keep the rate they were issued with.',
      'نرخ تبدیل کرنے کے لیے کلک کریں۔ پرانے نرخ ریکارڈ میں رہتے ہیں؛ جاری شدہ چالان پرانے نرخ پر ہی رہتے ہیں۔');
  String get notSet => _t('not set', 'مقرر نہیں');
  String get ratesForArea => _t('Show rates for area', 'علاقے کے نرخ دکھائیں');

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
