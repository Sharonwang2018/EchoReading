import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 非强制性打赏说明 Bottom Sheet（微信/支付宝收款码由 [assets/tips] 下图片替换）。
Future<void> showTipDonationSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '给 AI 老师加个鸡腿吧 🍗',
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '我是 Hi-Doo 的独立开发者。为了保证识别的精准度，我调用了目前最顶尖的 AI 接口，每一页识别都有真实的算力成本。',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _QrSlot(
                      label: '微信收款',
                      asset: 'assets/tips/wechat_receive.png',
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QrSlot(
                      label: '支付宝收款',
                      asset: 'assets/tips/alipay_receive.png',
                      cs: cs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '可选金额：加个鸡腿 ￥6.6 / 请喝咖啡 ￥9.9 / 随意打赏（金额无强制）',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '不方便的话也没关系，继续拍照/复述就好。若遇到“今日额度用完”，明天再来再用会更顺畅。',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.35,
                  color: cs.outlineVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('下次一定'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.only(bottom: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('继续使用', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// 由于底部已改为“纯金额提示”，鸡腿/咖啡/随意按钮不再需要可点击组件。

class _QrSlot extends StatelessWidget {
  const _QrSlot({required this.label, required this.asset, required this.cs});

  final String label;
  final String asset;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 56,
                    color: cs.outline,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
