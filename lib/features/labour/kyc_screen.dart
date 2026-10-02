import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

const kycDocs = ['AADHAAR', 'PAN', 'SELFIE', 'POLICE_VERIFICATION'];

final kycProvider = FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  final r = await ref.read(dioProvider).get('/api/kyc/documents/mine');
  return {for (final d in (r.data as List)) d['docType'] as String: Map<String, dynamic>.from(d)};
});

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});
  @override
  ConsumerState<KycScreen> createState() => _S();
}

class _S extends ConsumerState<KycScreen> {
  String? _busyDoc;

  Future<void> _upload(String docType) async {
    final picked = await ImagePicker().pickImage(
      source: docType == 'SELFIE' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _busyDoc = docType);
    try {
      final dio = ref.read(dioProvider);
      // 1) media-service -> S3 url   2) kyc-service stores docType + url
      final up = await dio.post('/api/media/upload',
          data: FormData.fromMap({'file': await MultipartFile.fromFile(picked.path, filename: picked.name), 'folder': 'kyc-docs'}));
      await dio.post('/api/kyc/documents', data: {'docType': docType, 'documentUrl': up.data['url']});
      ref.invalidate(kycProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiError(e))));
    } finally {
      if (mounted) setState(() => _busyDoc = null);
    }
  }

  Color _color(String? s) => switch (s) { 'VERIFIED' => Colors.green, 'REJECTED' => Colors.red, 'PENDING' => Colors.orange, _ => Colors.grey };

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(kycProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('KYC verification')),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiError(e))),
        data: (m) => ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Verified labour get more job offers. Upload clear photos of each document.'),
          const SizedBox(height: 12),
          for (final t in kycDocs)
            Card(
              child: ListTile(
                title: Text(t.replaceAll('_', ' ')),
                subtitle: Text(
                    '${m[t]?['status'] ?? 'NOT SUBMITTED'}${(m[t]?['reviewNotes'] ?? '').toString().isNotEmpty ? '\n${m[t]!['reviewNotes']}' : ''}',
                    style: TextStyle(color: _color(m[t]?['status']))),
                trailing: _busyDoc == t
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: Icon(t == 'SELFIE' ? Icons.camera_alt_outlined : Icons.upload_file),
                        onPressed: m[t]?['status'] == 'VERIFIED' ? null : () => _upload(t),
                      ),
              ),
            ),
        ]),
      ),
    );
  }
}
