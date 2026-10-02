import 'package:intl/intl.dart';

/// Display formats used everywhere: PKR with thousand separators,
/// dates as DD-MM-YYYY, times in Asia/Karachi (UTC+5, no daylight saving).
class Fmt {
  const Fmt._();

  static const karachiOffset = Duration(hours: 5);
  static final _pkr = NumberFormat('#,##0', 'en_US');
  static final _pkr2 = NumberFormat('#,##0.00', 'en_US');
  static final _date = DateFormat('dd-MM-yyyy');
  static final _time = DateFormat('hh:mm a');

  /// `2000` -> `PKR 2,000`; keeps paisa only when present (`PKR 1,234.50`).
  static String pkr(num amount, {bool symbol = true}) {
    final whole = amount == amount.roundToDouble();
    final s = whole ? _pkr.format(amount) : _pkr2.format(amount);
    return symbol ? 'PKR $s' : s;
  }

  /// Wall-clock time in Karachi for a UTC (or any) instant.
  static DateTime karachi(DateTime t) {
    final u = t.toUtc().add(karachiOffset);
    return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
  }

  static DateTime karachiNow() => karachi(DateTime.now());

  static String date(DateTime t, {bool isDateOnly = false}) => _date.format(isDateOnly ? t : karachi(t));
  static String time(DateTime t) => _time.format(karachi(t));
  static String dateTime(DateTime t) => '${date(t)} ${time(t)}';

  /// Accepts `03001234567`, `0300-1234567`, `+923001234567`, `923001234567`
  /// and returns `0300-1234567`, or null when it is not a Pakistani mobile number.
  static String? normalizePhone(String input) {
    var d = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('92') && d.length == 12) d = '0${d.substring(2)}';
    if (d.length == 10 && d.startsWith('3')) d = '0$d';
    if (!RegExp(r'^03[0-9]{9}$').hasMatch(d)) return null;
    return '${d.substring(0, 4)}-${d.substring(4)}';
  }

  /// `0300-1234567` -> `923001234567` (for wa.me links).
  static String whatsappNumber(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return d.startsWith('0') ? '92${d.substring(1)}' : d;
  }
}
