import 'package:flutter/material.dart';

import 'auth.dart';
import 'discussion_page.dart';
import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'gold_header.dart';
import 'login_page.dart';
import 'post_card.dart';
import 'user_avatar.dart';

/// 「我的」这个 tab：资料 + 我发的帖 + 退出登录
class ProfileTab extends StatefulWidget {
  final AuthStore auth;
  final FlarumApi api;
  final bool isZh;

  const ProfileTab({
    super.key,
    required this.auth,
    required this.api,
    this.isZh = true,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<Discussion>? _mine;
  bool _loading = false;
  String? _error;

  bool get _zh => widget.isZh;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    if (widget.auth.isLoggedIn) _loadMine();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// 登录态一变（App 启动时恢复登录 / 刚登录 / 退出）就跟着变。
  /// 必须监听：冷启动时 restore() 是异步的，initState 那一刻通常还没登录，
  /// 只靠 initState 会出现"已登录但「我发的帖」一片空白"。
  void _onAuthChanged() {
    if (!mounted) return;
    if (widget.auth.isLoggedIn) {
      setState(() {});
      if (_mine == null && !_loading) _loadMine();
    } else {
      setState(() {
        _mine = null;
        _error = null;
      });
    }
  }

  Future<void> _loadMine({bool silent = false}) async {
    final u = widget.auth.user;
    if (u == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await widget.api.fetchDiscussions(
        authorUsername: u.username,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _mine = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && (_mine?.isNotEmpty ?? false)) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginPage(auth: widget.auth, isZh: _zh),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _mine = null;
        _error = null;
      });
      _loadMine();
    }
  }

  Future<void> _confirmLogout() async {
    final zh = _zh;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(zh ? '退出登录？' : 'Sign out?'),
        content: Text(zh ? '退出后要重新输密码才能发帖' : 'You will need to sign in again to post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              zh ? '再想想' : 'Cancel',
              style: const TextStyle(color: Color(0xFF9A9A9A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              zh ? '退出' : 'Sign out',
              style: const TextStyle(color: Color(0xFFD9534F)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.auth.logout();
      if (!mounted) return;
      setState(() {
        _mine = null;
        _error = null;
      });
    }
  }

  Future<void> _open(Discussion d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          discussion: d,
          api: widget.api,
          auth: widget.auth,
          isZh: _zh,
        ),
      ),
    );
    // 可能在里面回了句，回来悄悄刷一下
    if (mounted) await _loadMine(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final zh = _zh;
    final user = widget.auth.user;

    return Column(
      children: [
        GoldHeader(
          title: zh ? '我的' : 'Profile',
          subtitle: user == null
              ? (zh ? '还没登录' : 'Not signed in')
              : '@${user.username}',
        ),
        Expanded(
          child: !widget.auth.isLoggedIn
              ? _signedOut(zh)
              : RefreshIndicator(
                  color: kBrandGold,
                  onRefresh: () => _loadMine(silent: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                    children: [
                      _userCard(zh, user!),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: kBrandGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            zh ? '我发的帖' : 'My posts',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._buildMine(zh),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildMine(bool zh) {
    if (_loading && _mine == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 30),
          child: Center(
            child: CircularProgressIndicator(color: kBrandGold),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9A9A9A))),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _loadMine(),
                child: Text(zh ? '重试' : 'Retry',
                    style: const TextStyle(color: kBrandGoldDark)),
              ),
            ],
          ),
        ),
      ];
    }
    final list = _mine;
    if (list == null) return const [SizedBox.shrink()];
    if (list.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            zh ? '还没发过帖子' : 'No posts yet',
            style: const TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
          ),
        ),
      ];
    }
    return list
        .map((d) => PostCard(discussion: d, isZh: zh, onTap: () => _open(d)))
        .toList();
  }

  Widget _userCard(bool zh, Author user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(author: user, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9A9A9A)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _confirmLogout,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB03A36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(zh ? '退出' : 'Sign out',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _signedOut(bool zh) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded,
                size: 54, color: kBrandGold.withValues(alpha: 0.6)),
            const SizedBox(height: 18),
            Text(
              zh ? '还没登录' : 'Not signed in',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              zh ? '登录后才能发帖、回复，也能看到自己发过的帖'
                  : 'Sign in to post, reply and see your own posts',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 170,
              height: 46,
              child: FilledButton(
                onPressed: _openLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: kBrandGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: Text(zh ? '去登录' : 'Sign in',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
