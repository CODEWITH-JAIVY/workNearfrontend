import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _S();
}

class _S extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false;
  String _type = 'CUSTOMER';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final c = ref.read(authProvider.notifier);
    final busy = auth.isLoading;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 40),
          Text('WorkNear', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 4),
          const Text('Skilled labour near you — or work near you'),
          const SizedBox(height: 28),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          if (_signup) ...[
            const SizedBox(height: 12),
            TextField(controller: _mobile, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number')),
          ],
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true,
              decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _signup ? '8+ chars, upper, lower and a digit' : null)),
          if (_signup) ...[
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CUSTOMER', label: Text('I need work done')),
                ButtonSegment(value: 'LABOUR', label: Text('I do the work')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy
                ? null
                : () => _signup
                    ? c.signup(_email.text.trim(), _mobile.text.trim(), _pass.text, _type)
                    : c.login(_email.text.trim(), _pass.text),
            child: busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_signup ? 'Create account' : 'Login'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : c.google,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Continue with Google'),
          ),
          if (auth.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(apiError(auth.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextButton(
            onPressed: () => setState(() => _signup = !_signup),
            child: Text(_signup ? 'Have an account? Login' : 'New here? Sign up'),
          ),
        ]),
      ),
    );
  }
}
