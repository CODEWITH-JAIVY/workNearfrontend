import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

/// POST /api/reviews {jobId, revieweeId, reviewerType: CUSTOMER|LABOUR, rating 1-5, comment}
Future<void> showRateSheet(BuildContext context, WidgetRef ref,
    {required int jobId, required int revieweeId, required String reviewerType}) {
  int stars = 5;
  final comment = TextEditingController();
  bool busy = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rate your experience', style: Theme.of(ctx).textTheme.titleMedium),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 34),
                onPressed: () => set(() => stars = i),
              ),
          ]),
          TextField(controller: comment, maxLines: 2, decoration: const InputDecoration(labelText: 'Comment (optional)')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() => busy = true);
                    try {
                      await ref.read(dioProvider).post('/api/reviews', data: {
                        'jobId': jobId, 'revieweeId': revieweeId, 'reviewerType': reviewerType,
                        'rating': stars, 'comment': comment.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your review')));
                      }
                    } catch (e) {
                      set(() => busy = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(apiError(e))));
                    }
                  },
            child: const Text('Submit'),
          ),
        ]),
      ),
    ),
  );
}
