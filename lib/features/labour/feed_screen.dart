import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/socket_service.dart';
import '../customer/post_job_screen.dart' show currentPosition;

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _S();
}

class _S extends ConsumerState<FeedScreen> {
  final _offers = <Job>[];
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _loadAvailability() async {
    try {
      final r = await ref.read(dioProvider).get('/api/labour/me');
      if (mounted) setState(() => _available = r.data['availableToday'] == true);
      if (_available) _pushLocation();
    } catch (_) {}
  }

  /// Matching is location based, so the backend must know where this labour is.
  Future<void> _pushLocation() async {
    try {
      final p = await currentPosition();
      await ref.read(dioProvider).post('/api/labour/me/location', data: {'lat': p.latitude, 'lon': p.longitude});
    } catch (e) {
      _snack(apiError(e));
    }
  }

  Future<void> _toggle(bool v) async {
    try {
      if (v) await _pushLocation();
      await ref.read(dioProvider).post('/api/labour/me/availability', queryParameters: {'available': v});
      setState(() => _available = v);
    } catch (e) {
      _snack(apiError(e));
    }
  }

  Future<void> _onEvent(AppEvent e) async {
    if (e.type != 'NEW_JOB_AVAILABLE') return;
    try {
      final r = await ref.read(dioProvider).get('/api/jobs/${e.data['jobId']}');
      final job = Job.fromJson(r.data as Map<String, dynamic>);
      if (job.isOpen && mounted && !_offers.any((o) => o.id == job.id)) {
        setState(() => _offers.insert(0, job));
      }
    } catch (_) {}
  }

  Future<void> _accept(Job j) async {
    try {
      // Redis Lua lock server-side: exactly one labour wins
      await ref.read(dioProvider).post('/api/jobs/${j.id}/accept');
      setState(() => _offers.removeWhere((o) => o.id == j.id));
      if (mounted) context.push('/job/${j.id}');
    } catch (e) {
      setState(() => _offers.removeWhere((o) => o.id == j.id));
      _snack('Too late — ${apiError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(eventsProvider, (_, n) {
      final e = n.value;
      if (e != null) _onEvent(e);
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs near you')),
      body: Column(children: [
        SwitchListTile(
          title: const Text('Available for work today'),
          subtitle: const Text('Share my location & receive job offers'),
          value: _available,
          onChanged: _toggle,
        ),
        const Divider(height: 1),
        Expanded(
          child: _offers.isEmpty
              ? Center(child: Text(_available ? 'Waiting for jobs…' : 'Turn on availability to get offers'))
              : ListView.builder(
                  itemCount: _offers.length,
                  itemBuilder: (_, i) {
                    final j = _offers[i];
                    return Card(
                      child: ListTile(
                        title: Text(j.title),
                        subtitle: Text('${j.address ?? ''}${j.budget != null ? '  •  ₹${j.budget!.toStringAsFixed(0)}' : ''}'),
                        trailing: FilledButton(onPressed: () => _accept(j), child: const Text('Accept')),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
