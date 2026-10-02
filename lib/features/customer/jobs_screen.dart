import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/socket_service.dart';

final myJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final r = await ref.read(dioProvider).get('/api/jobs/mine');
  final list = (r.data as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
  list.sort((a, b) => b.id.compareTo(a.id));
  return list;
});

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(eventsProvider, (_, n) {
      if (n.value?.type == 'JOB_ACCEPTED') {
        ref.invalidate(myJobsProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('A labour accepted your job!')));
      }
    });
    final jobs = ref.watch(myJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My jobs')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Post job'),
        onPressed: () async {
          await context.push('/post');
          ref.invalidate(myJobsProvider);
        },
      ),
      body: jobs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiError(e))),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.refresh(myJobsProvider.future),
          child: list.isEmpty
              ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No jobs yet — post your first one'))])
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final j = list[i];
                    return Card(
                      child: ListTile(
                        title: Text(j.title),
                        subtitle: Text('${j.labourType}${j.budget != null ? '  •  ₹${j.budget!.toStringAsFixed(0)}' : ''}'),
                        trailing: Chip(label: Text(j.status)),
                        onTap: () async {
                          await context.push('/job/${j.id}');
                          ref.invalidate(myJobsProvider);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
