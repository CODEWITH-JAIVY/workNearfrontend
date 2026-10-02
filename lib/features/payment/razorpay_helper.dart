import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/config.dart';

/// Wraps Razorpay checkout. Wallet crediting happens SERVER-side via the Razorpay webhook,
/// so this only reports whether the checkout itself succeeded.
class RazorpayHelper {
  final _rp = Razorpay();
  void Function(String msg, bool ok)? onResult;

  RazorpayHelper() {
    _rp.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse r) => onResult?.call('Payment successful', true));
    _rp.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse r) => onResult?.call(r.message ?? 'Payment failed', false));
    _rp.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
  }

  void open({required String orderId, required double amountRupees}) {
    if (Config.razorpayKey.isEmpty) {
      onResult?.call('Set --dart-define=RAZORPAY_KEY=rzp_test_xxx', false);
      return;
    }
    _rp.open({
      'key': Config.razorpayKey,
      'order_id': orderId,
      'amount': (amountRupees * 100).round(), // paise
      'currency': 'INR',
      'name': 'WorkNear',
      'description': 'Job payment',
    });
  }

  void dispose() => _rp.clear();
}
