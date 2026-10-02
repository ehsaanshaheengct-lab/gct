/// Dart mirrors of the Postgres enums in supabase/migrations/..._schema.sql.
/// `dbValue` is the exact database label; `en` / `ur` are display names.
library;

T _fromDb<T extends Enum>(List<T> values, String? v, T fallback) =>
    values.firstWhere((e) => (e as dynamic).dbValue == v, orElse: () => fallback);

enum UserRole {
  admin('admin', 'Admin', 'ایڈمن'),
  operator('operator', 'Office Operator', 'آفس آپریٹر'),
  driver('driver', 'Driver', 'ڈرائیور'),
  officer('officer', 'Officer (read-only)', 'افسر');

  const UserRole(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static UserRole fromDb(String? v) => _fromDb(values, v, UserRole.officer);

  bool get isOfficeUser => this != UserRole.driver;
  bool get canWrite => this == UserRole.admin || this == UserRole.operator;
}

enum VehicleCategory {
  sewer('sewer', 'Sewer', 'سیوریج'),
  water('water', 'Water', 'پانی'),
  heavyUtility('heavy_utility', 'Heavy Utility', 'بھاری مشینری'),
  smallUtility('small_utility', 'Small Utility', 'چھوٹی گاڑی');

  const VehicleCategory(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static VehicleCategory fromDb(String? v) => _fromDb(values, v, VehicleCategory.sewer);
}

enum PricingUnit {
  perTrip('per_trip', 'per trip', 'فی چکر', 'trips', 'چکر'),
  perHour('per_hour', 'per hour', 'فی گھنٹہ', 'hours', 'گھنٹے'),
  perDay('per_day', 'per day', 'فی دن', 'days', 'دن');

  const PricingUnit(this.dbValue, this.en, this.ur, this.quantityEn, this.quantityUr);
  final String dbValue, en, ur, quantityEn, quantityUr;
  static PricingUnit fromDb(String? v) => _fromDb(values, v, PricingUnit.perTrip);

  /// Hours and days are entered by the operator; trips default to 1.
  bool get asksQuantity => this != PricingUnit.perTrip;
}

enum PaymentPolicy {
  payAfterService('pay_after_service', 'Pay after service', 'کام کے بعد ادائیگی'),
  payBeforeDispatch('pay_before_dispatch', 'Pay before dispatch', 'روانگی سے پہلے ادائیگی');

  const PaymentPolicy(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static PaymentPolicy fromDb(String? v) => _fromDb(values, v, PaymentPolicy.payAfterService);
}

enum VehicleStatus {
  available('available', 'Available', 'دستیاب'),
  onJob('on_job', 'On Job', 'کام پر'),
  maintenance('maintenance', 'Maintenance', 'مرمت میں');

  const VehicleStatus(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static VehicleStatus fromDb(String? v) => _fromDb(values, v, VehicleStatus.available);
}

/// The work status of a challan.
enum ChallanStatus {
  generated('generated', 'Generated', 'جاری شدہ'),
  assigned('assigned', 'Assigned', 'تفویض شدہ'),
  started('started', 'Started', 'روانہ'),
  reached('reached', 'Reached', 'پہنچ گیا'),
  done('done', 'Done', 'کام مکمل'),
  cancelled('cancelled', 'Cancelled', 'منسوخ');

  const ChallanStatus(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static ChallanStatus fromDb(String? v) => _fromDb(values, v, ChallanStatus.generated);

  bool get isActiveJob => this == assigned || this == started || this == reached;
  bool get isFinal => this == done || this == cancelled;
}

/// The money status of a challan. Only the payment provider can set [paid].
enum PaymentStatus {
  unpaid('unpaid', 'Unpaid', 'غیر ادا شدہ'),
  paid('paid', 'Paid', 'ادا شدہ'),
  expired('expired', 'Expired', 'میعاد ختم');

  const PaymentStatus(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static PaymentStatus fromDb(String? v) => _fromDb(values, v, PaymentStatus.unpaid);
}

/// The single label shown in lists (`challans.display_status`).
enum DisplayStatus {
  generated('generated', 'Generated', 'جاری شدہ'),
  assigned('assigned', 'Assigned', 'تفویض شدہ'),
  started('started', 'Started', 'روانہ'),
  reached('reached', 'Reached', 'پہنچ گیا'),
  done('done', 'Done (unpaid)', 'مکمل (غیر ادا شدہ)'),
  paid('paid', 'Paid', 'ادا شدہ'),
  cancelled('cancelled', 'Cancelled', 'منسوخ'),
  expired('expired', 'Expired', 'میعاد ختم');

  const DisplayStatus(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static DisplayStatus fromDb(String? v) => _fromDb(values, v, DisplayStatus.generated);
}

enum RequestChannel {
  call('call', 'Call', 'فون'),
  sms('sms', 'SMS', 'ایس ایم ایس'),
  whatsapp('whatsapp', 'WhatsApp', 'واٹس ایپ'),
  walkIn('walk_in', 'Walk-in', 'دفتر آمد');

  const RequestChannel(this.dbValue, this.en, this.ur);
  final String dbValue, en, ur;
  static RequestChannel fromDb(String? v) => _fromDb(values, v, RequestChannel.call);
}

enum AmountSource {
  tariff('tariff', 'Tariff'),
  manual('manual', 'Manual');

  const AmountSource(this.dbValue, this.en);
  final String dbValue, en;
  static AmountSource fromDb(String? v) => _fromDb(values, v, AmountSource.tariff);
}
