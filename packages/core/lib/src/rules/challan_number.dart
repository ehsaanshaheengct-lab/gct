/// Challan numbers `WASA-<TEHSIL>-<YYYY>-<6 digits>` and 18-digit payment
/// references. Numbers are issued by the database; this formats and checks them.
class ChallanNumber {
  const ChallanNumber({required this.tehsilCode, required this.year, required this.sequence});

  final String tehsilCode;
  final int year;
  final int sequence;

  static final _re = RegExp(r'^WASA-([A-Z]{2,5})-(\d{4})-(\d{6})$');
  static final _ref = RegExp(r'^\d{18}$');

  @override
  String toString() => 'WASA-$tehsilCode-$year-${sequence.toString().padLeft(6, '0')}';

  static ChallanNumber? tryParse(String s) {
    final m = _re.firstMatch(s.trim().toUpperCase());
    if (m == null) return null;
    return ChallanNumber(tehsilCode: m[1]!, year: int.parse(m[2]!), sequence: int.parse(m[3]!));
  }

  static bool isValidPaymentRef(String s) => _ref.hasMatch(s);

  /// `401120260000011234` -> `4011 2026 0000 0112 34` (easier to read out on the phone).
  static String groupRef(String ref) {
    final b = StringBuffer();
    for (var i = 0; i < ref.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(ref[i]);
    }
    return b.toString();
  }
}
