import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';

Future<Position> currentPosition() async {
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw 'Location permission is needed';
  }
  return Geolocator.getCurrentPosition();
}

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});
  @override
  ConsumerState<PostJobScreen> createState() => _S();
}

class _S extends ConsumerState<PostJobScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _skills = TextEditingController();
  final _addr = TextEditingController();
  final _budget = TextEditingController();
  String _type = labourTypes.first;
  double _radius = 5;
  double _minRating = 0;
  bool _busy = false;

  Future<void> _post() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final pos = await currentPosition();
      await ref.read(dioProvider).post('/api/jobs', data: {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'requiredLabourType': _type,
        'skillsRequired': _skills.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'minRating': _minRating == 0 ? null : _minRating,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'addressText': _addr.text.trim(),
        'budget': double.tryParse(_budget.text),
        'radiusKm': _radius,
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Post a job')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'What do you need?')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type of labour'),
            items: labourTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills (comma separated)', hintText: 'pipe, tap, leak')),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Details')),
          const SizedBox(height: 12),
          TextField(controller: _addr, decoration: const InputDecoration(labelText: 'Address / landmark')),
          const SizedBox(height: 12),
          TextField(controller: _budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget (₹)')),
          const SizedBox(height: 16),
          Text('Search radius: ${_radius.toStringAsFixed(0)} km'),
          Slider(value: _radius, min: 1, max: 25, divisions: 24, onChanged: (v) => setState(() => _radius = v)),
          Text('Minimum labour rating: ${_minRating == 0 ? 'any' : _minRating.toStringAsFixed(1)}'),
          Slider(value: _minRating, min: 0, max: 5, divisions: 10, onChanged: (v) => setState(() => _minRating = v)),
          const Text('Job location = your current GPS position.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _post, child: Text(_busy ? 'Posting…' : 'Find labour near me')),
        ]),
      );
}
