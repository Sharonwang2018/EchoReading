import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/screens/photo_read_page_screen.dart';
import 'package:echo_reading/screens/scan_book_screen.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 视觉金字塔：品牌区 > 功能卡片
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!EnvConfig.isConfigured) return;
    try {
      final userInfo = await ApiAuthService.getUserInfo();
      if (mounted) {
        setState(() => _isLoggedIn = userInfo != null && userInfo.uuid.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoggedIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (EnvConfig.isConfigured)
            if (_isLoggedIn)
              PopupMenuButton<String>(
                icon: const Icon(Icons.person_rounded),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await ApiAuthService.signOut();
                    _checkAuth();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded),
                        SizedBox(width: 8),
                        Text('退出登录'),
                      ],
                    ),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (ok == true) _checkAuth();
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('登录'),
              ),
        ],
        title: Text(
          'Hi-Doo 绘读',
          style: GoogleFonts.quicksand(
            fontSize: ResponsiveLayout.isTablet(context) ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1a1a1a),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '会读，更会说 | Read it, Speak it.',
              style: GoogleFonts.quicksand(
                fontSize: ResponsiveLayout.isTablet(context) ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          Padding(
            padding: ResponsiveLayout.padding(context),
            child: ResponsiveLayout.isTablet(context)
                ? _TabletLayout(
                    scanTap: () => _push(context, const ScanBookScreen()),
                    photoTap: () => _push(context, const PhotoReadPageScreen()),
                  )
                : _PhoneLayout(
                    scanTap: () => _push(context, const ScanBookScreen()),
                    photoTap: () => _push(context, const PhotoReadPageScreen()),
                  ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({required this.scanTap, required this.photoTap});

  final VoidCallback scanTap;
  final VoidCallback photoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _MenuCard(
          icon: Icons.qr_code_scanner_rounded,
          title: '扫码录入书籍',
          subtitle: '扫描 ISBN 录入书籍，支持复述或共读记录',
          onTap: scanTap,
        ),
        const SizedBox(height: 12),
        _MenuCard(
          icon: Icons.camera_alt_rounded,
          title: '拍照读页',
          subtitle: '翻到哪页拍哪页，AI 读给你听，不存全书无侵权',
          onTap: photoTap,
        ),
      ],
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.scanTap, required this.photoTap});

  final VoidCallback scanTap;
  final VoidCallback photoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MenuCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '扫码录入书籍',
                  subtitle: '扫描 ISBN 录入书籍，支持复述或共读记录',
                  onTap: scanTap,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MenuCard(
                  icon: Icons.camera_alt_rounded,
                  title: '拍照读页',
                  subtitle: '翻到哪页拍哪页，AI 读给你听，不存全书无侵权',
                  onTap: photoTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final iconSz = ResponsiveLayout.iconSize(context);
    final padding = ResponsiveLayout.cardPadding(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: isTablet
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(padding),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        size: iconSz * 1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: padding),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    SizedBox(height: padding * 0.5),
                    Icon(Icons.chevron_right_rounded, size: iconSz),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: iconSz,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: iconSz),
                  ],
                ),
        ),
      ),
    );
  }
}
