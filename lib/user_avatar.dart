import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'flarum_api.dart';
import 'glass_nav_bar.dart';

/// 用户头像：有图就用图，没图就用名字首字生成一个金色圆形头像
class UserAvatar extends StatelessWidget {
  final Author? author;
  final double size;

  const UserAvatar({super.key, this.author, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final name = author?.displayName ?? '';
    final url = author?.avatarUrl;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _letter(name),
          errorWidget: (_, __, ___) => _letter(name),
        ),
      );
    }
    return _letter(name);
  }

  Widget _letter(String name) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFDCC08C), kBrandGoldDark],
        ),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
