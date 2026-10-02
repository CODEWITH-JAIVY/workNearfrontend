import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/push_service.dart';
import '../../core/socket_service.dart';
import '../customer/jobs_screen.dart';
import '../labour/feed_screen.dart';
import '../labour/kyc_screen.dart';
import '../labour/wallet_screen.dart';
import '../profile/profile_screen.dart';

class Shell extends ConsumerStatefulWidget {
  final bool labour;
  const Shell({super.key, required this.labour});
  @override
  ConsumerState<Shell> createState() => _S();
}

class _S extends ConsumerState<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    ref.read(socketProvider); // opens the notification WebSocket
    PushService.register(ref.read(dioProvider)); // FCM token -> backend (no-op if Firebase absent)
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.labour
        ? <(String, IconData, Widget)>[
            ('Jobs', Icons.work_outline, const FeedScreen()),
            ('Wallet', Icons.account_balance_wallet_outlined, const WalletScreen()),
            ('KYC', Icons.verified_user_outlined, const KycScreen()),
            ('Profile', Icons.person_outline, const ProfileScreen(labour: true)),
          ]
        : <(String, IconData, Widget)>[
            ('My jobs', Icons.list_alt, const JobsScreen()),
            ('Profile', Icons.person_outline, const ProfileScreen(labour: false)),
          ];
    return Scaffold(
      body: IndexedStack(index: _i, children: [for (final t in tabs) t.$3]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)],
      ),
    );
  }
}
