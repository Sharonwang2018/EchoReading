import 'package:flutter/material.dart';

/// iPad 适配：内容最大宽度、断点、响应式布局
class ResponsiveLayout {
  static const double _tabletBreakpoint = 600;
  static const double _desktopBreakpoint = 900;
  static const double _maxContentWidth = 560;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= _tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= _desktopBreakpoint;
  }

  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width > _maxContentWidth ? _maxContentWidth : width;
  }

  /// 将子组件限制在合理宽度内并居中（iPad 上不会铺满整屏）
  static Widget constrainToMaxWidth(BuildContext context, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }

  /// 响应式内边距
  static EdgeInsets padding(BuildContext context) {
    final base = 16.0;
    if (isTablet(context)) return EdgeInsets.all(base * 1.5);
    return EdgeInsets.all(base);
  }

  /// 响应式卡片内边距
  static double cardPadding(BuildContext context) {
    return isTablet(context) ? 20 : 14;
  }

  /// 响应式图标/按钮尺寸
  static double iconSize(BuildContext context, {double base = 28}) {
    return isTablet(context) ? base * 1.2 : base;
  }
}
