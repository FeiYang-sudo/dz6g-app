import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// 论坛接口地址（Flarum）
const String kApiBase = 'https://dz6g.ccwu.cc/board/api';

// ================================
//  数据模型
// ================================

/// 用户
class Author {
  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const Author({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    final a = json['attributes'] as Map<String, dynamic>? ?? const {};
    return Author(
      id: int.tryParse('${json['id']}') ?? 0,
      username: '${a['username'] ?? ''}',
      displayName: '${a['displayName'] ?? a['username'] ?? '匿名'}',
      avatarUrl: a['avatarUrl'] as String?,
    );
  }
}

/// 帖子（主题）
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

  const Discussion({
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

/// 楼层
class Post {
  final int id;
  final int number;
  final String contentHtml;
  final DateTime createdAt;
  final Author? author;
  final int likesCount;

  const Post({
    required this.id,
    required this.number,
    required this.contentHtml,
    required this.createdAt,
    this.author,
    this.likesCount = 0,
  });
}

/// 登录成功后拿到的东西
class AuthSession {
  final String token;
  final Author user;

  const AuthSession({required this.token, required this.user});
}

/// 接口出错 —— message 一律是可以直接给用户看的中文
class FlarumException implements Exception {
  final String message;
  const FlarumException(this.message);

  @override
  String toString() => message;
}

// ================================
//  客户端
// ================================

class FlarumApi {
  final String baseUrl;
  final http.Client _client;

  /// 登录后设置，之后所有请求自动带上
  String? token;

  FlarumApi({this.baseUrl = kApiBase, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': 'Dz6gApp/1.0',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Token $token',
      };

  // ---------------- 读 ----------------

  /// 帖子列表（分页）
  Future<List<Discussion>> fetchDiscussions({
    int offset = 0,
    int limit = 20,
    int? authorId,
  }) async {
    final uri = Uri.parse('$baseUrl/discussions').replace(queryParameters: {
      'include': 'user,lastPostedUser,firstPost',
      'sort': '-lastPostedAt',
      'page[offset]': '$offset',
      'page[limit]': '$limit',
      if (authorId != null) 'filter[author]': '$authorId',
    });

    final json = await _request('GET', uri);
    final authors = _collectAuthors(json['included']);

    return (json['data'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final a = item['attributes'] as Map<String, dynamic>;
      final rel = item['relationships'] as Map<String, dynamic>? ?? const {};

      return Discussion(
        id: int.tryParse('${item['id']}') ?? 0,
        title: '${a['title'] ?? ''}',
        slug: '${a['slug'] ?? ''}',
        commentCount: (a['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseTime(a['createdAt']),
        isSticky: a['isSticky'] == true,
        author: _lookupAuthor(authors, rel['user']),
        lastPostedUser: _lookupAuthor(authors, rel['lastPostedUser']),
        lastPostedAt: _parseNullableTime(a['lastPostedAt']),
        snippet: stripHtml(
          _findIncludedContent(json['included'], rel['firstPost']),
        ),
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

    final json = await _request('GET', uri);
    final authors = _collectAuthors(json['included']);

    return (json['data'] as List).map((raw) {
      final item = raw as Map<String, dynamic>;
      final a = item['attributes'] as Map<String, dynamic>;
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

  // ---------------- 登录 / 写 ----------------

  /// 登录。成功后会把这个实例的 token 设好（后续请求自动带认证）
  Future<AuthSession> login(String identification, String password) async {
    final json = await _request(
      'POST',
      Uri.parse('$baseUrl/token'),
      body: {
        'identification': identification,
        'password': password,
        'remember': true,
      },
      authErrorMessage: '账号或密码不对',
    );

    final t = '${json['token']}';
    final uid = int.tryParse('${json['userId']}') ?? 0;
    if (t.isEmpty || t == 'null' || uid == 0) {
      throw const FlarumException('登录失败，论坛没返回登录凭证');
    }

    token = t;
    final user = await fetchUser(uid);
    return AuthSession(token: t, user: user);
  }

  /// 取某个用户资料（也用来验证 token 还有没有效）
  Future<Author> fetchUser(int id) async {
    final json = await _request('GET', Uri.parse('$baseUrl/users/$id'));
    return Author.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// 发新帖
  Future<void> createDiscussion({
    required String title,
    required String content,
  }) async {
    await _request('POST', Uri.parse('$baseUrl/discussions'), body: {
      'data': {
        'type': 'discussions',
        'attributes': {'title': title, 'content': content},
      },
    });
  }

  /// 回帖
  Future<void> createReply({
    required int discussionId,
    required String content,
  }) async {
    await _request('POST', Uri.parse('$baseUrl/posts'), body: {
      'data': {
        'type': 'posts',
        'attributes': {'content': content},
        'relationships': {
          'discussion': {
            'data': {'type': 'discussions', 'id': '$discussionId'},
          },
        },
      },
    });
  }

  // ---------------- 内部：HTTP ----------------

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? authErrorMessage,
  }) async {
    late http.Response res;
    try {
      final req = http.Request(method, uri);
      req.headers.addAll(_headers);
      if (body != null) {
        req.headers['Content-Type'] = 'application/json; charset=utf-8';
        req.bodyBytes = utf8.encode(jsonEncode(body));
      }
      final streamed =
          await _client.send(req).timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const FlarumException('连不上论坛，检查一下网络');
    }

    // 先解析响应体（删除成功时是空的 204）
    final text = utf8.decode(res.bodyBytes).trim();
    Map<String, dynamic> json = const {};
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        json = const {};
      }
    }

    if (res.statusCode == 401) {
      throw FlarumException(authErrorMessage ?? '登录已过期，请重新登录');
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(json);
      throw FlarumException(detail ?? '论坛返回错误 (${res.statusCode})');
    }

    return json;
  }

  /// Flarum 的错误详情（{"errors":[{"detail":"..."}]}）
  String? _errorDetail(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        final detail = first['detail'] ?? first['code'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
      }
    }
    return null;
  }
}

// ================================
//  工具函数
// ================================

/// included 数组 → id 索引
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

/// 关系指针 {type,id} → 真用户
Author? _lookupAuthor(Map<int, Author> authors, dynamic relationship) {
  final data = (relationship as Map<String, dynamic>?)?['data'];
  if (data is! Map) return null;
  return authors[int.tryParse('${data['id']}') ?? 0];
}

/// 关系指针 → included 里那篇 posts 的 contentHtml
String _findIncludedContent(dynamic included, dynamic relationship) {
  final data = (relationship as Map<String, dynamic>?)?['data'];
  if (data is! Map) return '';
  final id = '${data['id']}';
  if (included is List) {
    for (final raw in included) {
      final item = raw as Map<String, dynamic>;
      if (item['type'] == 'posts' && '${item['id']}' == id) {
        final attrs = item['attributes'];
        if (attrs is Map) return '${attrs['contentHtml'] ?? ''}';
      }
    }
  }
  return '';
}

DateTime _parseTime(dynamic v) =>
    DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();

DateTime? _parseNullableTime(dynamic v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// Flarum 返回的是 HTML，列表里只要纯文本摘要
String stripHtml(String html) {
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

/// 时间显示成"3天前"
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
