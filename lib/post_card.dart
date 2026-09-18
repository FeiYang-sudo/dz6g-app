import 'package:flutter/material.dart';

import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'user_avatar.dart';

/// 帖子卡片（首页和「我的」都用它）
class PostCard extends StatelessWidget {
  final Discussion discussion;
  final bool isZh;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.discussion,
    required this.onTap,
    this.isZh = true,
  });

  @override
  Widget build(BuildContext context) {
    final d = discussion;

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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.isSticky) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6, top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: kBrandGold.withValues(alpha: 0.15),
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
                ],
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
            Row(
              children: [
                UserAvatar(author: d.lastPostedUser ?? d.author, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    d.lastPostedUser?.displayName ??
                        d.author?.displayName ??
                        '匿名',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8C8C8C)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  friendlyTime(d.lastPostedAt ?? d.createdAt, zh: isZh),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
                const Spacer(),
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 13, color: Color(0xFFB0B0B0)),
                const SizedBox(width: 3),
                Text(
                  '${d.commentCount}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
