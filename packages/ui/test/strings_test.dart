import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

void main() {
  test('rate text in both languages', () {
    expect(const S(AppLang.en).rateText(2000, PricingUnit.perTrip), 'PKR 2,000 / trip');
    expect(const S(AppLang.en).rateText(4000, PricingUnit.perHour), 'PKR 4,000 / hour');
    expect(const S(AppLang.ur).rateText(2000, PricingUnit.perTrip), 'PKR 2,000 فی چکر');
  });

  test('mixed-direction text is isolated', () {
    expect(S.auto('6,000 litres'), '\u20666,000 litres\u2069');
    expect(S.auto('غلام عباس'), 'غلام عباس');
  });
}
