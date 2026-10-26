import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';
import 'package:provider/provider.dart';
import '../models/comparison_models.dart';
import '../providers/app_state_provider.dart';
import '../theme/toastr_theme.dart';
import 'platform_login_webview_screen.dart';

/// Replicates Toastr's `platform_integration_screen.dart` with 100% local privacy.
class PlatformIntegrationScreen extends StatelessWidget {
  const PlatformIntegrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final foodPlatforms = state.platforms.values
        .where((p) => p.vertical == VerticalType.food)
        .toList();
    final groceryPlatforms = state.platforms.values
        .where((p) => p.vertical == VerticalType.grocery)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connected Platforms',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ToastrTheme.cardSurface,
              border: Border.all(color: ToastrTheme.primaryYellow.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: ToastrTheme.primaryYellow, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '100% On-Device Session Vault: Unlike the cloud version of Toastr, your session cookies & tokens stay strictly on your phone and are never uploaded to any server.',
                    style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'FOOD DELIVERY PLATFORMS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: ToastrTheme.primaryYellow,
            ),
          ),
          const SizedBox(height: 10),
          ...foodPlatforms.map((p) => _PlatformTile(platform: p)),
          const SizedBox(height: 22),
          const Text(
            'QUICK-COMMERCE GROCERY PLATFORMS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: ToastrTheme.neonGreen,
            ),
          ),
          const SizedBox(height: 10),
          ...groceryPlatforms.map((p) => _PlatformTile(platform: p)),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final PlatformInfo platform;

  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ToastrTheme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: platform.isConnected
              ? ToastrTheme.neonGreen.withOpacity(0.7)
              : ToastrTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: platform.brandColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: platform.brandColor, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              platform.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: platform.brandColor,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      platform.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: platform.isConnected
                            ? ToastrTheme.neonGreen.withOpacity(0.18)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        platform.isConnected ? 'LINKED' : 'GUEST MODE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: platform.isConnected
                              ? ToastrTheme.neonGreen
                              : Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  platform.isConnected
                      ? 'Synced locally • Real-time account coupons & cart enabled'
                      : 'Connect account for personalized coupons & member delivery fees',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeoPopButton(
            color: platform.isConnected
                ? ToastrTheme.surface
                : ToastrTheme.primaryYellow,
            onTapUp: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlatformLoginWebViewScreen(platform: platform),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                platform.isConnected ? 'RE-SYNC' : 'CONNECT',
                style: TextStyle(
                  color: platform.isConnected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
