import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/wasa_core.dart';

void main() {
  group('Tariff calculation', () {
    test('per trip: rate x trips', () {
      final q = TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perTrip);
      expect(q.amount, 2000);
      expect(TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perTrip, quantity: 2).amount, 4000);
      expect(q.source, AmountSource.tariff);
    });

    test('per hour: rate x hours, half hours allowed', () {
      expect(TariffQuote.fromTariff(rate: 4000, unit: PricingUnit.perHour, quantity: 3).amount, 12000);
      expect(TariffQuote.fromTariff(rate: 1500, unit: PricingUnit.perHour, quantity: 2.5).amount, 3750);
    });

    test('per day', () {
      expect(TariffQuote.fromTariff(rate: 5000, unit: PricingUnit.perDay, quantity: 2).amount, 10000);
    });

    test('rejects bad quantities', () {
      expect(() => TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perTrip, quantity: 1.5),
          throwsA(isA<RuleException>()));
      expect(() => TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perHour, quantity: 0),
          throwsA(isA<RuleException>()));
      expect(() => TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perHour, quantity: 1.3),
          throwsA(isA<RuleException>()));
      expect(() => TariffQuote.fromTariff(rate: -1, unit: PricingUnit.perTrip), throwsA(isA<RuleException>()));
    });

    test('manual override needs a reason', () {
      final q = TariffQuote.fromTariff(rate: 2000, unit: PricingUnit.perTrip);
      expect(() => q.withOverride(1500, '  '), throwsA(isA<RuleException>()));
      final m = q.withOverride(1500, 'Mosque: 25% concession');
      expect(m.amount, 1500);
      expect(m.source, AmountSource.manual);
      expect(m.rate, 2000);
    });
  });

  group('Challan numbering', () {
    test('format and parse', () {
      const n = ChallanNumber(tehsilCode: 'BKR', year: 2026, sequence: 7);
      expect(n.toString(), 'WASA-BKR-2026-000007');
      final p = ChallanNumber.tryParse('wasa-bkr-2026-000123')!;
      expect(p.sequence, 123);
      expect(p.year, 2026);
      expect(ChallanNumber.tryParse('WASA-BKR-26-1'), isNull);
    });

    test('payment reference', () {
      expect(ChallanNumber.isValidPaymentRef('401120260000011234'), isTrue);
      expect(ChallanNumber.isValidPaymentRef('40112026000001123'), isFalse);
      expect(ChallanNumber.groupRef('401120260000011234'), '4011 2026 0000 0112 34');
    });
  });

  group('Status transitions', () {
    test('happy path', () {
      expect(StatusMachine.canMove(ChallanStatus.generated, ChallanStatus.assigned), isTrue);
      expect(StatusMachine.driverNext(ChallanStatus.assigned), ChallanStatus.started);
      expect(StatusMachine.driverNext(ChallanStatus.started), ChallanStatus.reached);
      expect(StatusMachine.driverNext(ChallanStatus.reached), ChallanStatus.done);
      expect(StatusMachine.driverNext(ChallanStatus.done), isNull);
    });

    test('no skipping and no going back', () {
      expect(StatusMachine.canMove(ChallanStatus.generated, ChallanStatus.done), isFalse);
      expect(StatusMachine.canMove(ChallanStatus.assigned, ChallanStatus.reached), isFalse);
      expect(StatusMachine.canMove(ChallanStatus.done, ChallanStatus.started), isFalse);
      expect(StatusMachine.canMove(ChallanStatus.cancelled, ChallanStatus.assigned), isFalse);
    });

    test('paid challans cannot be cancelled', () {
      expect(StatusMachine.canCancel(status: ChallanStatus.generated, payment: PaymentStatus.unpaid), isTrue);
      expect(StatusMachine.canCancel(status: ChallanStatus.generated, payment: PaymentStatus.paid), isFalse);
      expect(StatusMachine.canCancel(status: ChallanStatus.done, payment: PaymentStatus.unpaid), isFalse);
    });
  });

  group('Pay before dispatch', () {
    test('pay-after types can be assigned unpaid', () {
      expect(
          StatusMachine.canAssign(
              status: ChallanStatus.generated, policy: PaymentPolicy.payAfterService, payment: PaymentStatus.unpaid),
          isTrue);
    });
    test('pay-before types need payment first', () {
      expect(
          StatusMachine.canAssign(
              status: ChallanStatus.generated, policy: PaymentPolicy.payBeforeDispatch, payment: PaymentStatus.unpaid),
          isFalse);
      expect(
          StatusMachine.canAssign(
              status: ChallanStatus.generated, policy: PaymentPolicy.payBeforeDispatch, payment: PaymentStatus.paid),
          isTrue);
    });
  });

  group('QR signing', () {
    // Vector computed in Postgres:
    // select left(encode(extensions.hmac('WASA-BKR-2026-000001|401120260000011234|2000.00','test-key-123','sha256'),'hex'),32)
    const pgSignature = 'a94d7e8dc7c559077bcf3302365cdac6';

    test('matches the database signer', () {
      expect(
          ChallanQr.sign(
              key: 'test-key-123', challanNo: 'WASA-BKR-2026-000001', paymentRef: '401120260000011234', amount: 2000),
          pgSignature);
      expect(ChallanQr.amountText(1500.5), '1500.50');
    });

    test('encode / parse round trip', () {
      const qr = ChallanQr(
          challanNo: 'WASA-BKR-2026-000001', paymentRef: '401120260000011234', amount: 2000, signature: pgSignature);
      final s = qr.encode();
      expect(s, 'WASA1|WASA-BKR-2026-000001|401120260000011234|2000.00|$pgSignature');
      final back = ChallanQr.tryParse(s)!;
      expect(back.challanNo, qr.challanNo);
      expect(back.amount, 2000);
      expect(ChallanQr.tryParse('hello'), isNull);
      expect(ChallanQr.tryParse('WASA1|a|b|x|d'), isNull);
    });

    test('a changed amount breaks the signature', () {
      final good = ChallanQr.sign(key: 'k', challanNo: 'N', paymentRef: 'R', amount: 2000);
      final bad = ChallanQr.sign(key: 'k', challanNo: 'N', paymentRef: 'R', amount: 200);
      expect(good, isNot(bad));
    });
  });

  group('Formatting', () {
    test('PKR', () {
      expect(Fmt.pkr(2000), 'PKR 2,000');
      expect(Fmt.pkr(1234567.5), 'PKR 1,234,567.50');
    });
    test('dates are DD-MM-YYYY in Karachi time', () {
      expect(Fmt.date(DateTime.utc(2026, 10, 1, 20, 0)), '02-10-2026');
    });
    test('phone numbers', () {
      expect(Fmt.normalizePhone('03001234567'), '0300-1234567');
      expect(Fmt.normalizePhone('+92 300 1234567'), '0300-1234567');
      expect(Fmt.normalizePhone('0300-123'), isNull);
      expect(Fmt.whatsappNumber('0300-1234567'), '923001234567');
    });
    test('login e-mail', () {
      expect(AppConfig.loginEmail(' Operator1 '), 'operator1@wasabhakkar.demo');
      expect(AppConfig.loginEmail('a@b.pk'), 'a@b.pk');
    });
  });
}
