import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 品牌金色（与官网 dz6g.ccwu.cc 一致）
const Color kBrandGold = Color(0xFFC9A96E);
const Color kBrandGoldDark = Color(0xFFA8874F);

/// ==========================================================
/// 液态玻璃底部导航栏（纯组件，不含任何页面逻辑）
///
/// 踩过的坑：
///   Positioned 必须是 Stack 的直接子节点！
///   如果把 Positioned 塞进 AnimatedBuilder 的 builder 里返回，
///   它就丢了父级 Stack 的约束，会跑到屏幕左上角 / 内容区。
///   正确做法：AnimatedBuilder 包在 Stack 外面，每帧重建整个 Stack。
/// ==========================================================
class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  /// 滚动因子 0~1：页面滚动越多，玻璃越"实"（模糊更强、更不透明）
  final double scrollFactor;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.scrollFactor = 0.0,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  static const double _navHeight = 66;
  static const double _indicatorHeight = 46;

  /// 滑动时长：短一点，配合线性曲线就是"干脆利落地滑过去"
  static const Duration _duration = Duration(milliseconds: 280);

  late final AnimationController _controller;

  /// 滑块位置（单位 = tab 索引的浮点数，如 1.37 表示在第1、2个 tab 之间）
  late Animation<double> _positionAnim;

  /// 上一次落定的位置，作为下一次动画的起点
  double _position = 0;

  @override
  void initState() {
    super.initState();
    _position = widget.currentIndex.toDouble();
    _controller = AnimationController(vsync: this, duration: _duration);
    _positionAnim = AlwaysStoppedAnimation<double>(_position);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      // 以「当前落点」为起点、新索引为终点，匀速直线滑过去
      _positionAnim = Tween<double>(
        begin: _position,
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          // 线性：全程匀速，不冲过头、不回弹
          curve: Curves.linear,
        ),
      );
      _position = widget.currentIndex.toDouble();
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // ⚠️ AnimatedBuilder 必须在 Stack 外面：这样每帧重建 Stack，
    //    里面的 Positioned 始终是 Stack 的直接子节点，定位才有效。
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Padding(
          // 悬浮胶囊：左右留边距 + 底部留白，不撑满屏宽
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 14 + safeBottom * 0.4,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final navWidth = constraints.maxWidth;
              final tabWidth = navWidth / widget.items.length;
              final t = _positionAnim.value;

              // 滑块尺寸全程不变，只改位置 —— 就是一条直线滑过去
              final indicatorWidth = tabWidth * 0.66;
              const indicatorHeight = _indicatorHeight;

              // 滑块中心对齐 tab 中心，所以左右各减半个宽度
              final center = t * tabWidth + tabWidth / 2;
              final indicatorLeft = center - indicatorWidth / 2;
              const indicatorTop = (_navHeight - indicatorHeight) / 2;

              return SizedBox(
                height: _navHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ① 玻璃底板（非 positioned 子节点 → 决定 Stack 尺寸）
                    _GlassBackdrop(
                      height: _navHeight,
                      scrollFactor: widget.scrollFactor,
                    ),

                    // ② 胶囊滑块 —— 放在图标"下面"当高亮底，不挡图标
                    Positioned(
                      left: indicatorLeft,
                      top: indicatorTop,
                      width: indicatorWidth,
                      height: indicatorHeight,
                      child: const _LiquidIndicator(),
                    ),

                    // ③ 图标 + 文字（最上层，保证点击和可读性）
                    SizedBox(
                      height: _navHeight,
                      child: Row(
                        children: List.generate(widget.items.length, (i) {
                          return Expanded(
                            child: _NavButton(
                              item: widget.items[i],
                              isSelected: i == widget.currentIndex,
                              onTap: () => widget.onTap(i),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ==========================================================
/// 玻璃底板：BackdropFilter 磨砂 + 半透明渐变 + 边缘高光
/// ==========================================================
class _GlassBackdrop extends StatelessWidget {
  final double height;
  final double scrollFactor;

  const _GlassBackdrop({required this.height, required this.scrollFactor});

  @override
  Widget build(BuildContext context) {
    final f = scrollFactor.clamp(0.0, 1.0);

    // 滚动越多 → 模糊半径越大、白度越高
    // （页面静止时内容清晰透出，滚动时自动"加密"成实心玻璃）
    final sigma = 14 + 16 * f;
    final topOpacity = 0.62 + 0.22 * f;
    final bottomOpacity = 0.46 + 0.24 * f;
    final radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              // 半透明白色渐变 = 玻璃本体
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(topOpacity),
                  Colors.white.withOpacity(bottomOpacity),
                ],
              ),
              // 一圈极细白边 = 玻璃的棱
              border: Border.all(
                color: Colors.white.withOpacity(0.85),
                width: 1,
              ),
            ),
            // 顶部一道横向高光 = 边缘折射感
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ==========================================================
/// 胶囊滑块（尺寸固定，只跟随动画平移）
/// ==========================================================
class _LiquidIndicator extends StatelessWidget {
  const _LiquidIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kBrandGold.withOpacity(0.30),
            kBrandGold.withOpacity(0.14),
          ],
        ),
        border: Border.all(
          color: kBrandGold.withOpacity(0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kBrandGold.withOpacity(0.26),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
}

/// ==========================================================
/// 单个 tab：图标 + 文字 + 点击内发光反馈
/// ==========================================================
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
  late final AnimationController _tap;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 240),
    );
    // 按下缩小到 86%，松手弹回
    _scale = Tween<double>(begin: 1.0, end: 0.86).animate(
      CurvedAnimation(parent: _tap, curve: Curves.easeOut),
    );
    // 点击时的内发光强度 0→1
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tap, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final color = selected ? kBrandGoldDark : const Color(0xFF8C8C8C);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap.forward(),
      onTapUp: (_) {
        _tap.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tap.reverse(),
      child: AnimatedBuilder(
        animation: _tap,
        builder: (context, _) {
          final g = _glow.value;
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // 点击内发光：按下时图标周围浮起一圈金色柔光
                boxShadow: g <= 0.01
                    ? null
                    : [
                        BoxShadow(
                          color: kBrandGold.withOpacity(0.45 * g),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.item.icon, size: 23, color: color),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 导航项数据模型
class NavItem {
  final String label;
  final IconData icon;

  const NavItem({required this.label, required this.icon});
}

/// ==========================================================
/// 国际化字符串（中 / 英）
/// ==========================================================
class AppLocalization {
  final Locale locale;

  AppLocalization(this.locale);

  String get languageCode => locale.languageCode;
  bool get isZh => locale.languageCode == 'zh';

  String get home => isZh ? '首页' : 'Home';
  String get feed => isZh ? '动态' : 'Feed';
  String get post => isZh ? '发布' : 'Post';
  String get profile => isZh ? '我的' : 'Me';
  String get title => isZh ? '校园墙' : 'Campus Wall';
  String get school =>
      isZh ? '邓州市第六高级中学' : 'Dengzhou No.6 High School';
  String get emptyHint => isZh ? '这个页面还在做' : 'Coming soon';
}

/// 本地化委托：把 AppLocalization 注入到 MaterialApp
class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const AppLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalization> load(Locale locale) async =>
      AppLocalization(locale);

  @override
  bool shouldReload(AppLocalizationDelegate old) => false;
}
