import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/read_log_with_book.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/services/learning_badges.dart';
import 'package:echo_reading/services/product_manifest_local.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 产品闭环说明：分级阅读、读-问-复述、双语与角色扮演、计费形态、师资结算（与投资人/教研反馈对齐）。
class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  Map<String, dynamic> _manifest = defaultProductManifestMap();
  List<ReadLogWithBook> _logs = const [];
  bool _loadingLogs = false;
  String? _logsError;

  @override
  void initState() {
    super.initState();
    _loadManifest();
    _loadLogsIfPossible();
  }

  Future<void> _loadManifest() async {
    if (!EnvConfig.isConfigured) return;
    try {
      final m = await ApiService.fetchProductManifest();
      if (mounted) setState(() => _manifest = m);
    } catch (_) {
      if (mounted) setState(() => _manifest = defaultProductManifestMap());
    }
  }

  Future<void> _loadLogsIfPossible() async {
    if (!EnvConfig.isConfigured) return;
    final user = await ApiAuthService.getUserInfo();
    if (user == null || user.uuid.isEmpty) return;
    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });
    try {
      final logs = await ApiService.fetchReadLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _loadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
          _logsError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflow = (_manifest['workflow'] as List<dynamic>?) ?? const [];
    final engagement = _manifest['engagement'] as Map<String, dynamic>?;
    final offerings = (_manifest['offerings'] as List<dynamic>?) ?? const [];
    final tutorOps = _manifest['tutor_ops'] as Map<String, dynamic>?;
    final badges = LearningBadges.fromLogs(_logs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '学习闭环 · 成长路线',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadManifest();
            await _loadLogsIfPossible();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ResponsiveLayout.padding(context).copyWith(bottom: 28),
            child: ResponsiveLayout.constrainToMaxWidth(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroStrip(context),
                  const SizedBox(height: 20),
                  Text(
                    '读 → 问 → 复述',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入 · 内化 · 输出',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...workflow.map<Widget>((dynamic step) {
                    final m = step as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PhaseCard(
                        title: m['title_zh'] as String? ?? '',
                        subtitle: m['body_zh'] as String? ?? '',
                      ),
                    );
                  }),
                  if (engagement != null) ...[
                    const SizedBox(height: 8),
                    _PhaseCard(
                      title: engagement['title_zh'] as String? ?? '',
                      subtitle: engagement['body_zh'] as String? ?? '',
                      icon: Icons.celebration_rounded,
                      tint: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    '成长小成就',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingLogs)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  else if (_logsError != null)
                    Text(
                      '成就数据暂不可用（${_logsError!}）',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (_logs.isEmpty && EnvConfig.isConfigured)
                    Text(
                      '登录并完成复述或共读后，这里会点亮徽章。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(170),
                          ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges
                        .map(
                          (b) => Chip(
                            avatar: Icon(
                              b.unlocked ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 20,
                              color: b.unlocked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).disabledColor,
                            ),
                            label: Text(b.titleZh),
                            side: BorderSide(
                              color: b.unlocked
                                  ? Theme.of(context).colorScheme.primary.withAlpha(120)
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '服务与计费（规划）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...offerings.map<Widget>((dynamic o) {
                    final om = o as Map<String, dynamic>;
                    final bullets = (om['bullets_zh'] as List<dynamic>?) ?? const [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(180),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                om['name_zh'] as String? ?? '',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ...bullets.map(
                                (dynamic line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '· ',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      Expanded(
                                        child: Text(
                                          line as String,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (tutorOps != null) ...[
                    const SizedBox(height: 8),
                    _PhaseCard(
                      title: tutorOps['title_zh'] as String? ?? '',
                      subtitle: tutorOps['body_zh'] as String? ?? '',
                      icon: Icons.groups_rounded,
                      tint: Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '在首页使用「扫码录入」与「AI 读书」即可完成上述闭环的主要步骤。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withAlpha(220),
            Theme.of(context).colorScheme.secondaryContainer.withAlpha(200),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _HeroMini(icon: Icons.menu_book_rounded, label: '读'),
          Icon(Icons.arrow_forward_rounded, size: 18),
          _HeroMini(icon: Icons.chat_bubble_outline_rounded, label: '问'),
          Icon(Icons.arrow_forward_rounded, size: 18),
          _HeroMini(icon: Icons.mic_rounded, label: '说'),
        ],
      ),
    );
  }
}

class _HeroMini extends StatelessWidget {
  const _HeroMini({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    this.tint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = tint ?? Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withAlpha(40),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: c),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
