import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

/// ============================================
/// 液态玻璃底部导航栏组件
/// 特性：悬浮胶囊、磨砂玻璃、弹簧物理动画
/// ============================================

class LiquidGlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final Locale locale;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.locale,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _indicatorAnimation;
  double _indicatorPosition = 0.0;
  double _lastIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _indicatorPosition = widget.currentIndex.toDouble();
    _lastIndex = widget.currentIndex.toDouble();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _indicatorAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      reverseCurve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildGlassBackground(),
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
          _buildIndicator(context),
        ],
      ),
    );
  }

  Widget _buildGlassBackground() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.6),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(BuildContext context) {
    final animatedPosition = Tween<double>(
      begin: _lastIndex,
      end: _indicatorPosition,
    ).animate(_indicatorAnimation);

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _indicatorAnimation,
        builder: (context, child) {
          final position = animatedPosition.value;
          final screenWidth = MediaQuery.of(context).size.width;
          final navWidth = screenWidth - 32 - 16;
          final tabWidth = navWidth / widget.items.length;
          final leftOffset = position * tabWidth + tabWidth * 0.15;
          final indicatorWidth = tabWidth * 0.7;

          return Positioned(
            left: leftOffset,
            width: indicatorWidth,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC9A96E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9A96E).withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
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
    final color = widget.isSelected
        ? const Color(0xFFC9A96E)
        : Colors.grey[600]!;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.item.icon,
                  color: color,
                  size: 26,
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
/// 国际化字符串
/// ============================================
class AppLocalization {
  final Locale locale;

  AppLocalization(this.locale);

  static AppLocalization of(BuildContext context) {
    return Localizations.of<AppLocalization>(context, AppLocalization)!;
  }

  String get home => locale.languageCode == 'en' ? 'Home' : '首页';
  String get feed => locale.languageCode == 'en' ? 'Feed' : '动态';
  String get post => locale.languageCode == 'en' ? 'Post' : '发布';
  String get profile => locale.languageCode == 'en' ? 'Profile' : '我的';
  String get title => locale.languageCode == 'en' ? 'Campus Wall' : '校园墙';
  String get school => locale.languageCode == 'en' 
      ? 'Dengzhou No.6 High School' 
      : '邓州市第六高级中学';
  String get postTitle => locale.languageCode == 'en' ? 'Post Title' : '帖子标题';
  String get postContent => locale.languageCode == 'en' 
      ? 'This is the post content...' 
      : '这是帖子的内容...';
}

/// ============================================
/// 本地化委托
/// ============================================
class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const AppLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalization> load(Locale locale) async {
    return AppLocalization(locale);
  }

  @override
  bool shouldReload(AppLocalizationDelegate old) => false;
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
  Locale _locale = const Locale('zh', 'CN');

  late final List<NavItem> _items;

  @override
  void initState() {
    super.initState();
    _updateItems();
  }

  void _updateItems() {
    final loc = AppLocalization(_locale);
    _items = [
      NavItem(label: loc.home, icon: Icons.home),
      NavItem(label: loc.feed, icon: Icons.explore),
      NavItem(label: loc.post, icon: Icons.add_circle),
      NavItem(label: loc.profile, icon: Icons.person),
    ];
  }

  void _toggleLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'zh' 
          ? const Locale('en', 'US') 
          : const Locale('zh', 'CN');
      _updateItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          _buildPageContent(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassNavBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: _items,
              locale: _locale,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleLanguage,
        backgroundColor: const Color(0xFFC9A96E),
        child: Text(
          _locale.languageCode == 'zh' ? 'EN' : '中文',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    final loc = AppLocalization(_locale);
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFC9A96E), Color(0xFFa08050)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 60, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    loc.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.school,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${loc.postTitle} $index'),
                    subtitle: Text(loc.postContent),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
              childCount: 10,
            ),
          ),
        ),
      ],
    );
  }
}
