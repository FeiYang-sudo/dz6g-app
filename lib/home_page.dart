import 'package:flutter/material.dart';

import 'discussion_page.dart';
import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'user_avatar.dart';

/// App 主页面：底部液态玻璃导航栏 + 四个 tab
/// 首页接的是论坛真实数据（Flarum API）
class CampusWallPage extends StatefulWidget {
  const CampusWallPage({super.key});

  @override
  State<CampusWallPage> createState() => _CampusWallPageState();
}

class _CampusWallPageState extends State<CampusWallPage> {
  static const int _pageSize = 15;

  final FlarumApi _api = FlarumApi();
  final ScrollController _scroll = ScrollController();

  final List<Discussion> _items = [];

  bool _loading = false; // 首次加载 / 下拉刷新
  bool _loadingMore = false; // 上拉加载下一页
  bool _hasMore = true;
  String? _error;

  /// 0~1，传给导航栏控制玻璃的模糊强度
  double _scrollFactor = 0;

  int _currentIndex = 0;
  Locale _locale = const Locale('zh', 'CN');

  bool get _isZh => _locale.languageCode == 'zh';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;

    // ① 玻璃模糊强度随滚动增强
    final f = (_scroll.offset / 160).clamp(0.0, 1.0);
    if ((f - _scrollFactor).abs() > 0.02) {
      setState(() => _scrollFactor = f);
    }

    // ② 快到底了自动加载下一页
    if (_scroll.position.pixels >
            _scroll.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  /// 首次加载 / 下拉刷新
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchDiscussions(offset: 0, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 上拉加载下一页
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
      // 加载更多失败不打断浏览，静默停住就好
      setState(() => _loadingMore = false);
    }
  }

  void _openDiscussion(Discussion d) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          discussion: d,
          api: _api,
          isZh: _isZh,
        ),
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      _locale = _isZh
          ? const Locale('en', 'US')
          : const Locale('zh', 'CN');
    });
  }

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
          _buildBody(loc),
          // 悬浮导航栏固定在最上层
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

  Widget _buildBody(AppLocalization loc) {
    // 除了首页，其它三个 tab 还是占位页
    if (_currentIndex != 0) {
      final items = _navItems(loc);
      return _PlaceholderPage(
        icon: items[_currentIndex].icon,
        label: items[_currentIndex].label,
        hint: loc.emptyHint,
      );
    }

    return RefreshIndicator(
      color: kBrandGold,
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(loc: loc, onToggleLanguage: _toggleLanguage),
          ),
          ..._buildListSlivers(loc),
        ],
      ),
    );
  }

  List<Widget> _buildListSlivers(AppLocalization loc) {
    // 加载中
    if (_loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 70),
            child: Center(
              child: CircularProgressIndicator(color: kBrandGold),
            ),
          ),
        ),
      ];
    }

    // 出错
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: _ErrorCard(message: _error!, onRetry: _load, isZh: _isZh),
        ),
      ];
    }

    // 空列表
    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Center(
              child: Text(
                _isZh ? '还没有人发帖，来当第一个吧' : 'No posts yet',
                style: const TextStyle(color: Color(0xFF9A9A9A)),
              ),
            ),
          ),
        ),
      ];
    }

    // 正常列表
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final d = _items[index];
              return _PostCard(
                discussion: d,
                isZh: _isZh,
                onTap: () => _openDiscussion(d),
              );
            },
            childCount: _items.length,
          ),
        ),
      ),
      // 底部：加载中转圈 / "到底啦"，顺便给悬浮导航栏留出 130px
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 130),
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
                    _hasMore ? '' : (_isZh ? '到底啦' : 'That is all'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0B0B0),
                    ),
                  ),
          ),
        ),
      ),
    ];
  }
}

/// ==========================================================
/// 顶部金色头部
/// ==========================================================
class _Header extends StatelessWidget {
  final AppLocalization loc;
  final VoidCallback onToggleLanguage;

  const _Header({required this.loc, required this.onToggleLanguage});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCC08C), kBrandGold, kBrandGoldDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              // 中英文切换放在顶部，不挡底部导航
              GestureDetector(
                onTap: onToggleLanguage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    loc.isZh ? 'EN' : '中文',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Icon(Icons.school_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            loc.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loc.school,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================================================
/// 帖子卡片（列表项）
/// ==========================================================
class _PostCard extends StatelessWidget {
  final Discussion discussion;
  final bool isZh;
  final VoidCallback onTap;

  const _PostCard({
    required this.discussion,
    required this.isZh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = discussion;
    final lastUser = d.lastPostedUser ?? d.author;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题（置顶的加个小标签）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.isSticky)
                  Container(
                    margin: const EdgeInsets.only(right: 6, top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: kBrandGold.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '置顶',
                      style: TextStyle(
                        fontSize: 10,
                        color: kBrandGoldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    d.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),

            // 正文摘要
            if (d.snippet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                d.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9A9A9A),
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // 底部：头像 + 名字 + 时间 + 回复数
            Row(
              children: [
                UserAvatar(author: lastUser, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    lastUser?.displayName ??
                        (isZh ? '匿名' : 'Anonymous'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8C8C8C),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  friendlyTime(d.lastPostedAt ?? d.createdAt, zh: isZh),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: Color(0xFFB0B0B0),
                ),
                const SizedBox(width: 3),
                Text(
                  '${d.commentCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表加载失败
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isZh;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: Color(0xFFCFCFCF),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF8C8C8C)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: kBrandGold),
            child: Text(isZh ? '重试' : 'Retry'),
          ),
        ],
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
          Icon(icon, size: 56, color: kBrandGold.withOpacity(0.5)),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
          ),
        ],
      ),
    );
  }
}
