import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'auth_controller.dart';

/// Shown to new Google users before the backend knows if they're CUSTOMER or LABOUR.
class SelectRoleScreen extends ConsumerStatefulWidget {
  const SelectRoleScreen({super.key});
  @override
  ConsumerState<SelectRoleScreen> createState() => _S();
}

class _S extends ConsumerState<SelectRoleScreen> {
  bool _busy = false;

  Future<void> _pick(String t) async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).selectRole(t);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('How will you use WorkNear?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              FilledButton(onPressed: _busy ? null : () => _pick('CUSTOMER'), child: const Text('I need work done')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _busy ? null : () => _pick('LABOUR'), child: const Text('I do the work')),
              TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Cancel')),
            ]),
          ),
        ),
      );
}
