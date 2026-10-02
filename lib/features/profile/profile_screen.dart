import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool labour;
  const ProfileScreen({super.key, required this.labour});
  @override
  ConsumerState<ProfileScreen> createState() => _S();
}

class _S extends ConsumerState<ProfileScreen> {
  final _c = <String, TextEditingController>{};
  String _labourType = labourTypes.first;
  String _employment = employmentTypes.first;
  Map<String, dynamic> _p = {};
  bool _loading = true, _saving = false;

  String get _path => widget.labour ? '/api/labour/me' : '/api/customers/me';
  List<String> get _fields => widget.labour
      ? ['name', 'skillsCsv', 'about', 'city']
      : ['name', 'addressLine', 'city', 'pincode'];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _c[f] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(dioProvider).get(_path);
      _p = Map<String, dynamic>.from(r.data);
      for (final f in _fields) {
        _c[f]!.text = (_p[f] ?? '').toString();
      }
      if (labourTypes.contains(_p['labourType'])) _labourType = _p['labourType'];
      if (employmentTypes.contains(_p['employmentType'])) _employment = _p['employmentType'];
    } catch (_) {
      // profile may not exist yet (created asynchronously after signup) -> empty form
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = {for (final f in _fields) f: _c[f]!.text.trim()};
      if (widget.labour) {
        body['labourType'] = _labourType;
        body['employmentType'] = _employment;
      }
      await ref.read(dioProvider).put(_path, data: body);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = {'name': 'Name', 'skillsCsv': 'Skills (comma separated)', 'about': 'About you', 'city': 'City', 'addressLine': 'Address', 'pincode': 'Pincode'};
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authProvider.notifier).logout()),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (widget.labour)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text('${(_p['rating'] ?? 0).toString()}  (${_p['ratingCount'] ?? 0} reviews)'),
                    trailing: Icon(_p['kycVerified'] == true ? Icons.verified : Icons.shield_outlined,
                        color: _p['kycVerified'] == true ? Colors.green : Colors.grey),
                  ),
                ),
              for (final f in _fields) ...[
                const SizedBox(height: 12),
                TextField(controller: _c[f], maxLines: f == 'about' ? 3 : 1, decoration: InputDecoration(labelText: label[f])),
              ],
              if (widget.labour) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _labourType,
                  decoration: const InputDecoration(labelText: 'Trade'),
                  items: labourTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _labourType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _employment,
                  decoration: const InputDecoration(labelText: 'Employment type'),
                  items: employmentTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _employment = v!),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
            ]),
    );
  }
}
