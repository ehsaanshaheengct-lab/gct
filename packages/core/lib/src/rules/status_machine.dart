import '../models/enums.dart';

/// Challan work-status rules. The database enforces the same table in
/// `challan_transition_allowed()`; the apps use this to show only valid buttons.
class StatusMachine {
  const StatusMachine._();

  static const Map<ChallanStatus, Set<ChallanStatus>> _next = {
    ChallanStatus.generated: {ChallanStatus.assigned, ChallanStatus.cancelled},
    ChallanStatus.assigned: {ChallanStatus.assigned, ChallanStatus.started, ChallanStatus.cancelled},
    ChallanStatus.started: {ChallanStatus.reached, ChallanStatus.cancelled},
    ChallanStatus.reached: {ChallanStatus.done, ChallanStatus.cancelled},
    ChallanStatus.done: {},
    ChallanStatus.cancelled: {},
  };

  static bool canMove(ChallanStatus from, ChallanStatus to) => _next[from]!.contains(to);

  /// The one big button in the driver app: Start -> Reached -> Done.
  static ChallanStatus? driverNext(ChallanStatus current) => switch (current) {
        ChallanStatus.assigned => ChallanStatus.started,
        ChallanStatus.started => ChallanStatus.reached,
        ChallanStatus.reached => ChallanStatus.done,
        _ => null,
      };

  /// Pay-before-dispatch types can only be assigned once paid.
  static bool canAssign({
    required ChallanStatus status,
    required PaymentPolicy policy,
    required PaymentStatus payment,
  }) {
    if (!canMove(status, ChallanStatus.assigned)) return false;
    if (policy == PaymentPolicy.payBeforeDispatch) return payment == PaymentStatus.paid;
    return true;
  }

  /// Paid challans cannot be cancelled (refunds are outside this system).
  static bool canCancel({required ChallanStatus status, required PaymentStatus payment}) =>
      payment != PaymentStatus.paid && canMove(status, ChallanStatus.cancelled);
}
