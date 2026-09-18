import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 论坛接口地址（Flarum）
const String kApiBase = 'https://dz6g.ccwu.cc/board/api';

// ==========================================================
// 数据模型
// ==========================================================

/// 发帖人 / 回复人
class Author {
  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  Author({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    final a = json['attributes'] as Map<String, dynamic>? ?? const {};
    final username = '${a['username'] ?? ''}';
    return Author(
      id: int.tryParse('${json['id']}') ?? 0,
      username: username,
      displayName: '${a['displayName'] ?? username}',
      avatarUrl: a['avatarUrl'] as String?,
    );
  }
}

/// 一个帖子（主题）
class Discussion {
  final int id;
  final String title;
  final String slug;
  final int commentCount;
  final DateTime createdAt;
  final bool isSticky;
  final Author? author;
  final Author? lastPostedUser;
  final DateTime? lastPostedAt;

  /// 首楼正文的纯文本摘要
  final String snippet;

  Discussion({
    required this.id,
    required this.title,
    required this.slug,
    required this.commentCount,
    required this.createdAt,
    required this.isSticky,
    this.author,
    this.lastPostedUser,
    this.lastPostedAt,
    this.snippet = '',
  });
}

/// 一个楼层（首楼 + 回复）
class Post {
  final int id;
  final int number;
  final String contentHtml;
  final DateTime createdAt;
  final Author? author;
  final int likesCount;

  Post({
    required this.id,
    required this.number,
    required this.contentHtml,
    required this.createdAt,
    this.author,
    this.likesCount = 0,
  });
}

/// 接口异常（把各种底层报错统一成一句人话）
class FlarumException implements Exception {
  final String message;
  FlarumException(this.message);

  @override
  String toString() => message;
}

// ==========================================================
// 客户端
// ==========================================================

class FlarumApi {
  final String baseUrl;
  final http.Client _client;

  FlarumApi({this.baseUrl = kApiBase, http.Client? client})
      : _client = client ?? http.Client();

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Dz6gApp/1.0',
  };

  /// 帖子列表（下拉刷新 / 上拉分页都用它）
  Future<List<Discussion>> fetchDiscussions({
    int offset = 0,
    int limit = 15,
  }) async {
    final uri = Uri.parse('$baseUrl/discussions').replace(queryParameters: {
      // firstPost 一起带回来，用来做列表里的正文摘要
      'include': 'user,lastPostedUser,firstPost',
      'sort': '-lastPostedAt',
      'page[offset]': '$offset',
      'page[limit]': '$limit',
    });

    final json = await _get(uri);
    final included = json['included'];
    final authors = _collectAuthors(included);

    return (json['data'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final a = item['attributes'] as Map<String, dynamic>? ?? const {};
      final rel = item['relationships'] as Map<String, dynamic>? ?? const {};

      return Discussion(
        id: int.tryParse('${item['id']}') ?? 0,
        title: '${a['title'] ?? '(无标题)'}',
        slug: '${a['slug'] ?? ''}',
        commentCount: (a['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseTime(a['createdAt']),
        isSticky: a['isSticky'] == true,
        author: _lookupAuthor(authors, rel['user']),
        lastPostedUser: _lookupAuthor(authors, rel['lastPostedUser']),
        lastPostedAt: _parseNullableTime(a['lastPostedAt']),
        snippet: stripHtml(_findPostContent(included, rel['firstPost'])),
      );
    }).toList();
  }

  /// 某个帖子下的全部楼层
  Future<List<Post>> fetchPosts(int discussionId) async {
    final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: {
      'filter[discussion]': '$discussionId',
      'sort': 'number',
      'include': 'user',
      'page[limit]': '50',
    });

    final json = await _get(uri);
    final authors = _collectAuthors(json['included']);

    return (json['data'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final a = item['attributes'] as Map<String, dynamic>? ?? const {};
      final rel = item['relationships'] as Map<String, dynamic>? ?? const {};

      return Post(
        id: int.tryParse('${item['id']}') ?? 0,
        number: (a['number'] as num?)?.toInt() ?? 0,
        contentHtml: '${a['contentHtml'] ?? ''}',
        createdAt: _parseTime(a['createdAt']),
        author: _lookupAuthor(authors, rel['user']),
        likesCount: (a['likesCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  // ---------------- 内部工具 ----------------

  Future<Map<String, dynamic>> _get(Uri uri) async {
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw FlarumException('网络超时了，检查一下网络再试');
    } catch (_) {
      throw FlarumException('连不上论坛，检查一下网络再试');
    }

    if (res.statusCode != 200) {
      throw FlarumException('论坛返回错误（${res.statusCode}）');
    }

    try {
      // 必须用 bodyBytes 手动解 UTF-8，否则中文会变乱码
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw FlarumException('返回的内容看不懂，可能被网络拦截了');
    }
  }
}

/// 从 included 里挑出所有用户，做成 id → Author 的查找表
Map<int, Author> _collectAuthors(dynamic included) {
  final map = <int, Author>{};
  if (included is! List) return map;
  for (final raw in included) {
    final item = raw as Map<String, dynamic>;
    if (item['type'] != 'users') continue;
    final author = Author.fromJson(item);
    map[author.id] = author;
  }
  return map;
}

/// relationships.user → 真正的 Author 对象
Author? _lookupAuthor(Map<int, Author> authors, dynamic relationship) {
  final data = (relationship as Map<String, dynamic>?)?['data'];
  if (data is! Map) return null;
  return authors[int.tryParse('${data['id']}') ?? 0];
}

/// relationships.firstPost → included 里那篇 post 的 contentHtml
String _findPostContent(dynamic included, dynamic relationship) {
  final data = (relationship as Map<String, dynamic>?)?['data'];
  if (data is! Map) return '';
  final id = '${data['id']}';
  if (included is List) {
    for (final raw in included) {
      final item = raw as Map<String, dynamic>;
      if (item['type'] == 'posts' && '${item['id']}' == id) {
        final attrs = item['attributes'] as Map<String, dynamic>? ?? const {};
        return '${attrs['contentHtml'] ?? ''}';
      }
    }
  }
  return '';
}

DateTime _parseTime(dynamic value) =>
    DateTime.tryParse('$value')?.toLocal() ?? DateTime.now();

DateTime? _parseNullableTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

/// Flarum 的正文是 HTML，列表里只要纯文本摘要
String stripHtml(String html) {
  if (html.isEmpty) return '';
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 把时间显示成"3天前"这种人话
String friendlyTime(DateTime time, {bool zh = true}) {
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return zh ? '刚刚' : 'just now';
  if (diff.inMinutes < 60) {
    return zh ? '${diff.inMinutes}分钟前' : '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return zh ? '${diff.inHours}小时前' : '${diff.inHours}h ago';
  }
  if (diff.inDays < 30) {
    return zh ? '${diff.inDays}天前' : '${diff.inDays}d ago';
  }
  return '${time.year}-${_two(time.month)}-${_two(time.day)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
