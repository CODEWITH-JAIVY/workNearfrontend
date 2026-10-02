import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';
import '../payment/razorpay_helper.dart';
import '../profile/rate_sheet.dart';

final jobProvider = FutureProvider.autoDispose.family<Job, int>((ref, id) async {
  final r = await ref.read(dioProvider).get('/api/jobs/$id');
  return Job.fromJson(r.data as Map<String, dynamic>);
});

class JobDetailScreen extends ConsumerStatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});
  @override
  ConsumerState<JobDetailScreen> createState() => _S();
}

class _S extends ConsumerState<JobDetailScreen> {
  late final RazorpayHelper _rp;

  @override
  void initState() {
    super.initState();
    _rp = RazorpayHelper()
      ..onResult = (msg, ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      };
  }

  @override
  void dispose() {
    _rp.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pay(Job job) async {
    final c = TextEditingController(text: job.budget?.toStringAsFixed(0) ?? '');
    final amt = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Pay for this job'),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, double.tryParse(c.text)), child: const Text('Pay')),
        ],
      ),
    );
    if (amt == null || amt <= 0) return;
    try {
      // amount in rupees: backend converts to paise
      final r = await ref.read(dioProvider).post('/api/payments/orders', data: {
        'jobId': job.id, 'customerId': job.customerId, 'labourId': job.acceptedLabourId, 'amount': amt,
      });
      _rp.open(orderId: r.data['razorpayOrderId'], amountRupees: (r.data['amount'] as num).toDouble());
    } catch (e) {
      _snack(apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).value;
    final job = ref.watch(jobProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text('Job #${widget.jobId}')),
      body: job.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiError(e))),
        data: (j) {
          final iAmCustomer = me?.userId == j.customerId;
          final otherId = iAmCustomer ? j.acceptedLabourId : j.customerId;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(j.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [Chip(label: Text(j.status)), Chip(label: Text(j.labourType))]),
            if ((j.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(j.description!)),
            if ((j.address ?? '').isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.place_outlined), title: Text(j.address!)),
            if (j.budget != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.currency_rupee), title: Text(j.budget!.toStringAsFixed(0))),
            const Divider(height: 32),
            if (!j.isAccepted) const Text('Waiting for a labour to accept…'),
            if (j.isAccepted) ...[
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
                onPressed: () => context.push('/chat/${j.id}'),
              ),
              const SizedBox(height: 8),
              if (iAmCustomer)
                FilledButton.tonalIcon(icon: const Icon(Icons.payments_outlined), label: const Text('Pay'), onPressed: () => _pay(j)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.star_outline),
                label: Text(iAmCustomer ? 'Rate the labour' : 'Rate the customer'),
                onPressed: otherId == null
                    ? null
                    : () => showRateSheet(context, ref, jobId: j.id, revieweeId: otherId, reviewerType: iAmCustomer ? 'CUSTOMER' : 'LABOUR'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
