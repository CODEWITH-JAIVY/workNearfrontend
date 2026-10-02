import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int jobId;
  const ChatScreen({super.key, required this.jobId});
  @override
  ConsumerState<ChatScreen> createState() => _S();
}

class _S extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <Map<String, dynamic>>[];
  IOWebSocketChannel? _ch;
  int? _me, _receiver;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dio = ref.read(dioProvider);
      _me = ref.read(authProvider).value?.userId;
      final job = Job.fromJson((await dio.get('/api/jobs/${widget.jobId}')).data);
      // backend needs receiverId on every message: the other participant of this job
      _receiver = _me == job.customerId ? job.acceptedLabourId : job.customerId;
      final hist = await dio.get('/api/chat/jobs/${widget.jobId}/messages');
      final token = await ref.read(tokenStorageProvider).access;
      final ch = IOWebSocketChannel.connect(
        Uri.parse('${Config.wsBase}/ws/chat?jobId=${widget.jobId}&userId=$_me'),
        headers: {'Authorization': 'Bearer $token'},
        pingInterval: const Duration(seconds: 30),
      );
      await ch.ready;
      ch.stream.listen(
        (raw) {
          if (!mounted) return;
          setState(() => _msgs.add(jsonDecode(raw as String) as Map<String, dynamic>));
          _toEnd();
        },
        onError: (_) => mounted ? setState(() => _error = 'Chat disconnected') : null,
        onDone: () => mounted ? setState(() => _error = 'Chat disconnected') : null,
      );
      if (!mounted) return ch.sink.close();
      setState(() {
        _ch = ch;
        _msgs.addAll(List<Map<String, dynamic>>.from((hist.data as List).map((e) => Map<String, dynamic>.from(e))));
      });
      _toEnd();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty || _ch == null || _receiver == null) return;
    _ch!.sink.add(jsonEncode({'jobId': widget.jobId, 'receiverId': _receiver, 'content': t}));
    // server does not echo to the sender, so add it locally
    setState(() => _msgs.add({'senderId': _me, 'content': t}));
    _input.clear();
    _toEnd();
  }

  @override
  void dispose() {
    _ch?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Job #${widget.jobId}')),
      body: Column(children: [
        if (_error != null) MaterialBanner(content: Text(_error!), actions: const [SizedBox()]),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final m = _msgs[i];
              final mine = (m['senderId'] as num?)?.toInt() == _me;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: mine ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                  child: Text('${m['content']}'),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Row(children: [
            Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _input, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Message'))),),
            IconButton(icon: const Icon(Icons.send), onPressed: _send),
          ]),
        ),
      ]),
    );
  }
}
