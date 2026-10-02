class Config {
  /// Emulator -> host: 10.0.2.2. Real phone: --dart-define=API_BASE=http://<LAN-IP>:8080
  static const baseUrl =
      String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8080');
  static String get wsBase => baseUrl.replaceFirst('http', 'ws');

  /// Razorpay PUBLIC key id (rzp_test_...). Never put the secret in the app.
  static const razorpayKey = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');

  /// Deep-link scheme the backend redirects to after Google login (FRONTEND_URL=worknear://auth)
  static const authScheme = 'worknear';
}
