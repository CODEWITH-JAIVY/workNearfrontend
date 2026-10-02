import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

final walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final uid = ref.watch(authProvider).value?.userId;
  try {
    final r = await ref.read(dioProvider).get('/api/payments/wallet/$uid');
    return Map<String, dynamic>.from(r.data);
  } catch (_) {
    return {'balance': 0.0, 'lifetimeEarnings': 0.0}; // backend throws when no wallet exists yet
  }
});

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(walletProvider.future),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          w.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiError(e)),
            data: (d) => Column(children: [
              Card(
                child: ListTile(
                  title: const Text('Balance (pending payout)'),
                  trailing: Text('₹${(d['balance'] as num).toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Lifetime earnings'),
                  trailing: Text('₹${(d['lifetimeEarnings'] as num).toStringAsFixed(2)}'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
