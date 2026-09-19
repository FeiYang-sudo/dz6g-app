import 'package:flutter/material.dart';

import 'auth.dart';
import 'compose_page.dart';
import 'discussion_page.dart';
import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'post_card.dart';
import 'profile_page.dart';

/// App 主页面：底部液态玻璃导航栏 + 四个 tab
/// 首页接的是论坛真实数据，发布/我的需要登录
class CampusWallPage extends StatefulWidget {
  const CampusWallPage({super.key});

  @override
  State<CampusWallPage> createState() => _CampusWallPageState();
}

class _CampusWallPageState extends State<CampusWallPage> {
  final FlarumApi _api = FlarumApi();
  late final AuthStore _auth = AuthStore(_api);
  final ScrollController _scroll = ScrollController();

  final List<Discussion> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  /// 上一页自动加载失败过，就先别再试，否则滚动事件会把请求打爆
  bool _moreFailed = false;
  String? _error;
  double _scrollFactor = 0;

  int _currentIndex = 0;
  Locale _locale = const Locale('zh', 'CN');

  bool get _isZh => _locale.languageCode == 'zh';

  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _auth.addListener(_onAuthChanged);
    // token 过期时自动退出登录，界面自己切回"去登录"
    _api.onUnauthorized = () {
      if (_auth.isLoggedIn) _auth.logout();
    };
    _auth.restore();
    _load();
  }

  @override
  void dispose() {
    _api.onUnauthorized = null;
    _auth.removeListener(_onAuthChanged);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _toggleLanguage() {
    setState(() {
      _locale = _isZh ? const Locale('en', 'US') : const Locale('zh', 'CN');
    });
  }

  // ---------------- 列表加载 ----------------

  void _onScroll() {
    if (!_scroll.hasClients) return;

    // ① 玻璃模糊强度跟着滚动走
    final f = (_scroll.offset / 160).clamp(0.0, 1.0);
    if ((f - _scrollFactor).abs() > 0.02) {
      setState(() => _scrollFactor = f);
    }

    // ② 快到底了自动加载下一页
    if (_scroll.position.pixels >
            _scroll.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        !_loading &&
        !_moreFailed &&
        _hasMore) {
      _loadMore();
    }
  }

  /// [silent] = 后台悄悄刷（下拉刷新 / 从帖子页返回）：
  /// 期间保留屏幕上已有的列表，不闪转圈；失败也不把列表擦掉。
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _api.fetchDiscussions(offset: 0, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= _pageSize;
        _moreFailed = false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // 屏幕上已经有帖子时，一次刷新失败不该把内容全擦掉
      if (silent && _items.isNotEmpty) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final list = await _api.fetchDiscussions(
        offset: _items.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _hasMore = list.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 失败就先别自动往下加载了，等用户自己下拉刷新
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  Future<void> _openDiscussion(Discussion d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          discussion: d,
          api: _api,
          auth: _auth,
          isZh: _isZh,
        ),
      ),
    );
    // 进帖子可能回了句，回来悄悄刷一下，让回复数和时间跟上
    if (mounted) await _load(silent: true);
  }

  /// 发帖成功后回调：回首页 + 刷新
  Future<void> _afterPosted() async {
    setState(() => _currentIndex = 0);
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    await _load(silent: true);
  }

  // ---------------- 界面 ----------------

  List<NavItem> _navItems(AppLocalization loc) => [
        NavItem(label: loc.home, icon: Icons.home_rounded),
        NavItem(label: loc.feed, icon: Icons.explore_rounded),
        NavItem(label: loc.post, icon: Icons.add_circle_outline_rounded),
        NavItem(label: loc.profile, icon: Icons.person_rounded),
      ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization(_locale);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            sizing: StackFit.expand,
            children: [
              _buildHomeTab(loc),
              _PlaceholderPage(
                icon: Icons.explore_rounded,
                label: loc.feed,
                hint: _isZh ? '这个页面还在做' : 'Coming soon',
              ),
              ComposeTab(
                auth: _auth,
                api: _api,
                isZh: _isZh,
                onPosted: _afterPosted,
              ),
              ProfileTab(auth: _auth, api: _api, isZh: _isZh),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassNavBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: _navItems(loc),
              scrollFactor: _scrollFactor,
            ),
          ),
        ],
      ),
    );
  }

  /// 首页。四个 tab 用 IndexedStack 装着——切走再切回来时，
  /// 「发布」里写了一半的草稿还在，「我的」也不用重新加载。
  Widget _buildHomeTab(AppLocalization loc) {
    return RefreshIndicator(
      color: kBrandGold,
      onRefresh: () => _load(silent: true),
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              loc: loc,
              isZh: _isZh,
              onToggleLanguage: _toggleLanguage,
            ),
          ),
          ..._buildListSlivers(loc),
        ],
      ),
    );
  }

  List<Widget> _buildListSlivers(AppLocalization loc) {
    // 屏幕上已经有帖子时不显示转圈（下拉刷新自己有那个转圈）
    if (_loading && _items.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: kBrandGold),
            ),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 0),
            child: Column(
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 46, color: Colors.black.withValues(alpha: 0.18)),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF8C8C8C)),
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => _load(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBrandGoldDark,
                    side: const BorderSide(color: kBrandGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 10),
                  ),
                  child: Text(_isZh ? '重试' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                _isZh ? '还没有人发帖，来当第一个吧' : 'No posts yet',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFFB0B0B0)),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => PostCard(
              discussion: _items[index],
              isZh: _isZh,
              onTap: () => _openDiscussion(_items[index]),
            ),
            childCount: _items.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 130),
          child: Center(
            child: _loadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kBrandGold,
                    ),
                  )
                : Text(
                    _hasMore ? '' : (_isZh ? '到底啦' : 'End'),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB0B0B0)),
                  ),
          ),
        ),
      ),
    ];
  }
}

/// 首页顶部：校名 + 校园墙 + 中英切换
class _Header extends StatelessWidget {
  final AppLocalization loc;
  final bool isZh;
  final VoidCallback onToggleLanguage;

  const _Header({
    required this.loc,
    required this.isZh,
    required this.onToggleLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBrandGoldDark, kBrandGold],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.school,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: onToggleLanguage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isZh ? 'EN' : '中',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 还没做的 tab
class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;

  const _PlaceholderPage({
    required this.icon,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: kBrandGold.withValues(alpha: 0.55)),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Color(0xFFA0A0A0)),
          ),
        ],
      ),
    );
  }
}
