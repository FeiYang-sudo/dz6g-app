import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'auth.dart';
import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'login_page.dart';
import 'user_avatar.dart';

/// 帖子详情页：标题 + 全部楼层 + 底部回复框
class DiscussionPage extends StatefulWidget {
  final Discussion discussion;
  final FlarumApi api;
  final AuthStore auth;
  final bool isZh;

  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.api,
    required this.auth,
    this.isZh = true,
  });

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _replyCtrl = TextEditingController();

  List<Post>? _posts;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _zh => widget.isZh;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _load();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _scroll.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  /// [silent] = 后台悄悄刷：不闪转圈，失败也不把已经看到的楼层擦掉
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await widget.api.fetchPosts(widget.discussion.id);
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && (_posts?.isNotEmpty ?? false)) {
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
    if (ok == true && mounted) setState(() {});
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? const Color(0xFFD9534F) : const Color(0xFF3C3C3C),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _send() async {
    final text = _replyCtrl.text.trim();
    if (_sending || text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await widget.api.createReply(
        discussionId: widget.discussion.id,
        content: text,
      );
      if (!mounted) return;
      _replyCtrl.clear();
      setState(() => _sending = false);
      await _load(silent: true);
      // 滚到最底下看自己的回复
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.discussion;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: kBrandGold,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          d.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: kBrandGold,
        onRefresh: () => _load(silent: true),
        child: _buildBody(),
      ),
      bottomNavigationBar: _replyBar(),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts == null) {
      return const Center(
        child: CircularProgressIndicator(color: kBrandGold),
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 110),
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
                  ),
                  child: Text(_zh ? '重试' : 'Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final posts = _posts ?? const <Post>[];
    if (posts.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Center(
              child: Text(
                _zh ? '这个帖子还没有内容' : 'Nothing here yet',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFFB0B0B0)),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: posts.length,
      itemBuilder: (context, i) => _PostTile(
        post: posts[i],
        isOp: posts[i].number == 1,
        zh: _zh,
      ),
    );
  }

  Widget _replyBar() {
    final zh = _zh;

    if (!widget.auth.isLoggedIn) {
      return SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _openLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandGoldDark,
                side: const BorderSide(color: kBrandGold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Text(zh ? '登录后回复' : 'Sign in to reply'),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 110),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _replyCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: zh ? '说点什么…' : 'Write a reply…',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Color(0xFFB0B0B0)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kBrandGold,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: kBrandGoldDark),
              tooltip: zh ? '发送' : 'Send',
            ),
          ],
        ),
      ),
    );
  }
}

/// 一层楼
class _PostTile extends StatelessWidget {
  final Post post;
  final bool isOp;
  final bool zh;

  const _PostTile({required this.post, required this.isOp, required this.zh});

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final name = author?.displayName ?? (zh ? '匿名' : 'Anonymous');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(author: author, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isOp) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: kBrandGold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '楼主',
                              style: TextStyle(
                                fontSize: 10,
                                color: kBrandGoldDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friendlyTime(post.createdAt, zh: zh),
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFFB0B0B0)),
                    ),
                  ],
                ),
              ),
              Text(
                '${post.number}楼',
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFFC4C4C4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Html(
            data: post.contentHtml,
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(14.5),
                lineHeight: const LineHeight(1.55),
                color: const Color(0xFF2B2B2B),
              ),
              'a': Style(color: kBrandGoldDark),
              'p': Style(margin: Margins.only(bottom: 6)),
            },
          ),
          if (post.likesCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 13, color: Color(0xFFE08A8A)),
                const SizedBox(width: 3),
                Text(
                  '${post.likesCount}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
