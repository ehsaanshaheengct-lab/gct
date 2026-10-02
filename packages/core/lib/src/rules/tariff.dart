import '../models/enums.dart';

/// Thrown for input the operator must correct (shown as a friendly message).
class RuleException implements Exception {
  const RuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The amount for a challan: rate x quantity from the tariff, or a manual
/// override that must carry a reason. Mirrors the database check
/// `amount = rate * quantity` and `manual_amount_needs_reason`.
class TariffQuote {
  const TariffQuote._({
    required this.rate,
    required this.unit,
    required this.quantity,
    required this.amount,
    required this.source,
    this.overrideReason,
  });

  final double rate;
  final PricingUnit unit;
  final double quantity;
  final double amount;
  final AmountSource source;
  final String? overrideReason;

  /// Rounds to paisa (2 decimals).
  static double round2(num v) => (v * 100).round() / 100;

  factory TariffQuote.fromTariff({required double rate, required PricingUnit unit, double quantity = 1}) {
    if (rate < 0) throw const RuleException('The rate cannot be negative.');
    if (quantity <= 0) throw const RuleException('Enter a quantity greater than zero.');
    if (unit == PricingUnit.perTrip && quantity != quantity.roundToDouble()) {
      throw const RuleException('Trips must be a whole number.');
    }
    if (unit != PricingUnit.perTrip && (quantity * 2) != (quantity * 2).roundToDouble()) {
      throw const RuleException('Hours and days can be entered in steps of 0.5.');
    }
    return TariffQuote._(
      rate: rate,
      unit: unit,
      quantity: quantity,
      amount: round2(rate * quantity),
      source: AmountSource.tariff,
    );
  }

  /// A manual amount replaces the tariff amount; the reason is logged.
  TariffQuote withOverride(double amount, String reason) {
    if (amount < 0) throw const RuleException('The amount cannot be negative.');
    if (reason.trim().isEmpty) throw const RuleException('Write a reason for changing the amount.');
    return TariffQuote._(
      rate: rate,
      unit: unit,
      quantity: quantity,
      amount: round2(amount),
      source: AmountSource.manual,
      overrideReason: reason.trim(),
    );
  }
}
