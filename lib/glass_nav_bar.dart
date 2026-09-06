import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter, Color;

/// ============================================
/// 液态玻璃底部导航栏组件
/// 特性：悬浮胶囊、磨砂玻璃、弹簧物理动画
/// ============================================

class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final double pageOffset; // 页面滚动偏移量 (0.0 - 1.0)

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.pageOffset = 0.0,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _indicatorAnimation;
  late Animation<double> _stretchAnimation;
  double _indicatorPosition = 0.0;
  double _lastIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _indicatorPosition = widget.currentIndex.toDouble();
    _lastIndex = widget.currentIndex.toDouble();

    // 弹簧动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    // 弹性插值器 - 模拟弹簧物理效果
    _indicatorAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    // 拉伸动画 - 滑动时的液态形变
    _stretchAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _animateToIndex(widget.currentIndex.toDouble());
    }
  }

  void _animateToIndex(double newIndex) {
    _lastIndex = _indicatorPosition;
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _indicatorPosition = newIndex;
        _lastIndex = newIndex;
      });
    });
  }

  /// 根据滚动偏移量动态调整玻璃效果强度
  double get _blurStrength {
    // 滚动时增加模糊强度，模拟景深变化
    return 15.0 + (widget.pageOffset * 10.0);
  }

  double get _opacity {
    // 滚动时略微增加透明度
    return 0.65 + (widget.pageOffset * 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: _buildGlassContainer(theme, isDark),
    );
  }

  Widget _buildGlassContainer(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 液态拉伸效果
        final stretch = _stretchAnimation.value;
        final scale = 1.0 + (stretch - 1.0) * 0.1;

        return Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 玻璃背景层
              _GlassBackground(
                blurStrength: _blurStrength,
                opacity: _opacity,
                isDark: isDark,
              ),
              // 内容层
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(widget.items.length, (index) {
                      return _NavButton(
                        item: widget.items[index],
                        isSelected: index == widget.currentIndex,
                        onTap: () => widget.onTap(index),
                      );
                    }),
                  ),
                ),
              ),
              // 液态滑块指示器
              _buildIndicator(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicator(ThemeData theme) {
    // 计算滑块位置 (基于当前动画状态)
    final animatedPosition = Tween<double>(
      begin: _lastIndex,
      end: _indicatorPosition,
    ).animate(_indicatorAnimation);

    // 根据拉伸动画计算滑块形变
    final stretch = _stretchAnimation.value;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 56,
      child: Stack(
        children: [
          // 液态滑块
          AnimatedBuilder(
            animation: _indicatorAnimation,
            builder: (context, child) {
              final position = animatedPosition.value;
              // 计算滑块的左右边距（每个tab平均分配）
              final containerWidth = MediaQuery.of(context).size.width - 32 - 16;
              final tabWidth = containerWidth / widget.items.length;
              final leftOffset = position * tabWidth + tabWidth * 0.15;
              final width = tabWidth * 0.7;

              return Positioned(
                left: leftOffset,
                bottom: 8,
                width: width,
                height: 40,
                child: _LiquidIndicator(stretch: stretch),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// ============================================
/// 液态玻璃背景组件
/// 实现 BackdropFilter 磨砂效果和边缘高光
/// ============================================
class _GlassBackground extends StatelessWidget {
  final double blurStrength;
  final double opacity;
  final bool isDark;

  const _GlassBackground({
    required this.blurStrength,
    required this.opacity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        // 液态玻璃核心：磨砂模糊效果
        backgroundBlendMode: BlendMode.srcOver,
        borderRadius: BorderRadius.circular(32),
        // 渐变背景 - 模拟环境折射
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? Colors.white.withOpacity(opacity * 0.15)
                : Colors.white.withOpacity(0.7),
            isDark
                ? Colors.white.withOpacity(opacity * 0.05)
                : Colors.white.withOpacity(0.5),
          ],
        ),
        // 边框 - 边缘高光效果
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.withOpacity(0.3),
          width: 0.5,
        ),
        // 阴影 - 悬浮感
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          // 顶部高光阴影 - 模拟光源
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      //  backdropFilter 实现磨砂玻璃效果（关键代码）
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength,
          sigmaY: blurStrength,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            // 内部渐变 - 增强液态感
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.9),
                isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.white.withOpacity(0.6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================
/// 液态滑块指示器
/// 实现水滴形变和流体效果
/// ============================================
class _LiquidIndicator extends StatelessWidget {
  final double stretch;

  const _LiquidIndicator({required this.stretch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      size: Size(double.infinity, 40),
      painter: _LiquidIndicatorPainter(
        stretch: stretch,
        isDark: isDark,
      ),
    );
  }
}

class _LiquidIndicatorPainter extends CustomPainter {
  final double stretch;
  final bool isDark;

  _LiquidIndicatorPainter({
    required this.stretch,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final width = size.width;

    // 液态拉伸形变 - 根据 stretch 值改变圆角
    final compressedHeight = height / stretch;

    // 水滴形状 - 底部略宽，顶部略窄
    final path = Path()
      // 左上弧线
      ..moveTo(0, compressedHeight * 0.3)
      ..quadraticBezierTo(
        width * 0.25,
        0,
        width * 0.5,
        0,
      )
      ..quadraticBezierTo(
        width * 0.75,
        0,
        width,
        compressedHeight * 0.3,
      )
      // 右侧弧线
      ..quadraticBezierTo(
        width,
        compressedHeight * 0.7,
        width * 0.9,
        compressedHeight,
      )
      // 底部弧线
      ..quadraticBezierTo(
        width * 0.5,
        compressedHeight * 1.1,
        width * 0.1,
        compressedHeight,
      )
      // 左侧弧线
      ..close();

    // 填充颜色 - 高光效果
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.25)
          : Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.fill
      // 抗锯齿
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);

    // 边缘高光 - 模拟光线折射
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(path, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidIndicatorPainter oldDelegate) {
    return oldDelegate.stretch != stretch || oldDelegate.isDark != isDark;
  }
}

/// ============================================
/// 导航按钮组件
/// ============================================
class _NavButton extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
    );

    // 点击反馈动画
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Curves.easeInOut,
      ),
    );

    // 内发光动画
    _glowAnimation = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(_NavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _tapController.forward();
      } else {
        _tapController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isSelected
        ? const Color(0xFFC9A96E)
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      child: AnimatedBuilder(
        animation: _tapController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 内发光效果
                if (widget.isSelected)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC9A96E).withOpacity(
                            _glowAnimation.value,
                          ),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                // 图标和文字
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.item.icon,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }
}

/// ============================================
/// 导航项数据模型
/// ============================================
class NavItem {
  final String label;
  final IconData icon;

  const NavItem({
    required this.label,
    required this.icon,
  });
}

/// ============================================
/// 主页面示例
/// ============================================
class GlassNavDemoPage extends StatefulWidget {
  const GlassNavDemoPage({super.key});

  @override
  State<GlassNavDemoPage> createState() => _GlassNavDemoPageState();
}

class _GlassNavDemoPageState extends State<GlassNavDemoPage> {
  int _currentIndex = 0;
  double _pageOffset = 0.0;

  final List<NavItem> _items = const [
    NavItem(label: '首页', icon: Icons.home),
    NavItem(label: '动态', icon: Icons.explore),
    NavItem(label: '发布', icon: Icons.add_circle),
    NavItem(label: '我的', icon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b0b0b),
      body: Stack(
        children: [
          // 页面内容 - 模拟滚动效果
          _buildPageContent(),
          // 液态玻璃导航栏
          LiquidGlassNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: _items,
            pageOffset: _pageOffset,
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent() {
    final colors = [
      const Color(0xFF1a1a2e),
      const Color(0xFF16213e),
      const Color(0xFF0f3460),
      const Color(0xFF533483),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.blur_on, size: 100, color: Color(0xFFC9A96E)),
            const SizedBox(height: 24),
            Text(
              '第 ${_currentIndex + 1} 页',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '滚动页面观察导航栏玻璃效果变化',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
