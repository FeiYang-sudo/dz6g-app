import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'user_avatar.dart';

/// 帖子详情页：标题 + 全部楼层（首楼 + 回复）
class DiscussionPage extends StatefulWidget {
  final Discussion discussion;
  final FlarumApi api;
  final bool isZh;

  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.api,
    this.isZh = true,
  });

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  late Future<List<Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPosts(widget.discussion.id);
  }

  void _reload() {
    setState(() {
      _future = widget.api.fetchPosts(widget.discussion.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.discussion;
    final zh = widget.isZh;

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
      body: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snap) {
          // 加载中
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrandGold),
            );
          }

          // 出错
          if (snap.hasError) {
            return _ErrorView(
              message: '${snap.error}',
              onRetry: _reload,
              isZh: zh,
            );
          }

          final posts = snap.data ?? const <Post>[];
          if (posts.isEmpty) {
            return Center(
              child: Text(zh ? '这个帖子还没有内容' : 'No content yet'),
            );
          }

          return RefreshIndicator(
            color: kBrandGold,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              // 第 0 项是帖子信息条，之后才是楼层
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _DiscussionMeta(discussion: d, isZh: zh);
                }
                return _PostTile(post: posts[index - 1], isZh: zh);
              },
            ),
          );
        },
      ),
    );
  }
}

/// 帖子信息条：谁发的、什么时候、多少回复
class _DiscussionMeta extends StatelessWidget {
  final Discussion discussion;
  final bool isZh;

  const _DiscussionMeta({required this.discussion, required this.isZh});

  @override
  Widget build(BuildContext context) {
    final d = discussion;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          UserAvatar(author: d.author, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d.author?.displayName ?? (isZh ? '匿名' : 'Anonymous'),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            friendlyTime(d.createdAt, zh: isZh),
            style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
          ),
        ],
      ),
    );
  }
}

/// 单个楼层
class _PostTile extends StatelessWidget {
  final Post post;
  final bool isZh;

  const _PostTile({required this.post, required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              UserAvatar(author: post.author, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author?.displayName ?? (isZh ? '匿名' : 'Anonymous'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      friendlyTime(post.createdAt, zh: isZh),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB0B0B0),
                      ),
                    ),
                  ],
                ),
              ),
              // 楼层号
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${post.number}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 正文：Flarum 给的是 HTML，交给 flutter_html 渲染
          Html(data: post.contentHtml),
          if (post.likesCount > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: Color(0xFFE0A0A0),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 出错了：给一句人话 + 重试按钮
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isZh;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFFCFCFCF),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: kBrandGold),
              child: Text(isZh ? '重试' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
