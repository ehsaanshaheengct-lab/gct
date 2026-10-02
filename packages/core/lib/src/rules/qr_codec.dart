import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The challan QR: `WASA1|<challan_no>|<payment_ref>|<amount>|<sig>`.
///
/// `sig` is the first 32 hex characters of HMAC-SHA256 over `no|ref|amount`
/// with a secret that lives only on the server (`private.app_secrets`).
/// The apps never hold the secret: they read the stored signature to draw the QR,
/// and call `verify_challan_qr()` to check a scanned one. [sign] exists so the
/// algorithm is documented and unit-tested against the database.
class ChallanQr {
  const ChallanQr({
    required this.challanNo,
    required this.paymentRef,
    required this.amount,
    required this.signature,
  });

  static const prefix = 'WASA1';

  final String challanNo;
  final String paymentRef;
  final double amount;
  final String signature;

  /// Same as Postgres `private.amount_text()`: two decimals, no separators.
  static String amountText(num amount) => amount.toStringAsFixed(2);

  String encode() => [prefix, challanNo, paymentRef, amountText(amount), signature].join('|');

  static ChallanQr? tryParse(String raw) {
    final p = raw.trim().split('|');
    if (p.length != 5 || p[0] != prefix) return null;
    final amount = double.tryParse(p[3]);
    if (amount == null) return null;
    return ChallanQr(challanNo: p[1], paymentRef: p[2], amount: amount, signature: p[4]);
  }

  static String sign({required String key, required String challanNo, required String paymentRef, required num amount}) {
    final mac = Hmac(sha256, utf8.encode(key)).convert(utf8.encode('$challanNo|$paymentRef|${amountText(amount)}'));
    return mac.toString().substring(0, 32);
  }
}
