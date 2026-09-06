import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const Dz6gApp());

class Dz6gApp extends StatelessWidget {
  const Dz6gApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园墙',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9A96E),
          secondary: Color(0xFF1a1a1a),
          surface: Color(0xFF2d2d2d),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const NotificationsScreen(),
    const NewPostScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _CustomBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _NavButton(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: '首页',
              index: 0,
              currentIndex: currentIndex,
              onTap: () => onTap(0),
            ),
            _NavButton(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications,
              label: '动态',
              index: 1,
              currentIndex: currentIndex,
              badge: 3,
              onTap: () => onTap(1),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFC9A96E), Color(0xFFa08050)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 32, color: Colors.black),
                ),
              ),
            ),
            _NavButton(
              icon: Icons.mail_outline,
              activeIcon: Icons.mail,
              label: '通知',
              index: 3,
              currentIndex: currentIndex,
              onTap: () => onTap(3),
            ),
            _NavButton(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: '我的',
              index: 4,
              currentIndex: currentIndex,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final int? badge;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? const Color(0xFFC9A96E) : Colors.grey,
                  size: 24,
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    right: 8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFFC9A96E) : Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// 首页 - 帖子列表
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> posts = [];
  Map<int, dynamic> discussionMap = {};
  Map<int, dynamic> userMap = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => loading = true);
    try {
      final response = await http.get(Uri.parse('https://dz6g.ccwu.cc/board/api/posts'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final postData = data['data'] as List;
        final included = (data['included'] as List?) ?? [];

        discussionMap = {};
        userMap = {};
        for (final item in included) {
          if (item['type'] == 'discussions') {
            discussionMap[item['id']] = item;
          } else if (item['type'] == 'users') {
            userMap[item['id']] = item;
          }
        }

        setState(() {
          posts = postData;
          loading = false;
        });
      }
    } catch (e) {
      print('加载失败: $e');
      setState(() => loading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) return '${diff.inDays}天前';
      if (diff.inHours > 0) return '${diff.inHours}小时前';
      if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
      return '刚刚';
    } catch (e) {
      return dateStr.substring(5, 16);
    }
  }

  String _extractText(String html) {
    return html
        .replaceAll('<p>', '')
        .replaceAll('</p>', '')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<strong>', '*')
        .replaceAll('</strong>', '*')
        .replaceAll('<em>', '*')
        .replaceAll('</em>', '*')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校园墙'),
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A96E)))
          : RefreshIndicator(
              onRefresh: _loadPosts,
              color: const Color(0xFFC9A96E),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final discussionId = post['relationships']['discussion']['data']['id'];
                  final discussion = discussionMap[discussionId];
                  final userId = post['relationships']['user']['data']?['id'];
                  final user = userMap[userId];
                  final content = _extractText(post['attributes']['contentHtml'] ?? '');
                  final username = user?['attributes']['username'] ?? '匿名用户';
                  final createdAt = post['attributes']['createdAt'] ?? '';
                  final isSticky = discussion?['attributes']['isSticky'] ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Card(
                      color: const Color(0xFF2d2d2d),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFC9A96E),
                                  child: Text(
                                    username[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          if (isSticky) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: const BoxDecoration(color: Color(0xFFC9A96E), borderRadius: BorderRadius.all(Radius.circular(4))),
                                              child: const Text('置顶', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(_formatDate(createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.grey),
                            if (content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  content.length > 200 ? '${content.substring(0, 200)}...' : content,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                                ),
                              ),
                            Row(
                              children: [
                                _StatItem(icon: Icons.reply, count: '${discussion?['attributes']['commentCount'] ?? 0}'),
                                const SizedBox(width: 16),
                                _StatItem(icon: Icons.favorite_border, count: '${post['attributes']['likesCount'] ?? 0}'),
                                const Spacer(),
                                _StatItem(icon: Icons.visibility, count: '${post['attributes']['viewCount'] ?? 0}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadPosts,
        backgroundColor: const Color(0xFFC9A96E),
        label: const Text('刷新'),
        icon: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String count;
  const _StatItem({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}

// 通知页面
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: ListView(
        children: const [
          _NotificationItem(icon: Icons.reply, title: '有人回复了你的帖子', time: '5分钟前'),
          _NotificationItem(icon: Icons.favorite, title: '有人点赞了你的帖子', time: '1小时前'),
          _NotificationItem(icon: Icons.person_add, title: '新用户加入了校园墙', time: '2小时前'),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  const _NotificationItem({required this.icon, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon, color: const Color(0xFFC9A96E))),
      title: Text(title),
      subtitle: Text(time, style: TextStyle(color: Colors.grey[600])),
      trailing: const CircleAvatar(radius: 4, backgroundColor: Color(0xFFC9A96E)),
    );
  }
}

// 发帖页面
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool posting = false;

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写标题和内容')));
      return;
    }
    setState(() => posting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => posting = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发帖成功')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发布帖子')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '内容', border: OutlineInputBorder()),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: posting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC9A96E), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: posting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('发布'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 我的页面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: const [_ProfileHeader(), _MenuSection()],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFC9A96E), Color(0xFF8B7355)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Color(0xFFC9A96E))),
          const SizedBox(width: 16),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('未登录', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('登录后体验完整功能', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFC9A96E)),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MenuItem(icon: Icons.forum, title: '我的帖子'),
        _MenuItem(icon: Icons.favorite, title: '我的收藏'),
        _MenuItem(icon: Icons.settings, title: '设置'),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  const _MenuItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFC9A96E)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }
}
