import 'package:flutter/material.dart';

import 'auth.dart';
import 'flarum_api.dart';
import 'glass_nav_bar.dart';
import 'gold_header.dart';
import 'login_page.dart';

/// 「发布」这个 tab 的内容：写标题 + 正文，发出去
class ComposeTab extends StatefulWidget {
  final AuthStore auth;
  final FlarumApi api;
  final bool isZh;

  /// 发成功之后通知外面（切回首页并刷新）
  final Future<void> Function() onPosted;

  const ComposeTab({
    super.key,
    required this.auth,
    required this.api,
    required this.onPosted,
    this.isZh = true,
  });

  @override
  State<ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<ComposeTab> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _busy = false;

  bool get _zh => widget.isZh;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginPage(auth: widget.auth, isZh: _zh),
      ),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_busy) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final zh = _zh;

    if (title.isEmpty) {
      _toast(zh ? '标题还没写' : 'Title is required');
      return;
    }
    if (content.isEmpty) {
      _toast(zh ? '正文还没写' : 'Content is required');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.api.createDiscussion(title: title, content: content);
      if (!mounted) return;
      _titleCtrl.clear();
      _contentCtrl.clear();
      setState(() => _busy = false);
      _toast(zh ? '发布成功' : 'Posted');
      await widget.onPosted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('$e', error: true);
    }
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
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final zh = _zh;

    return Column(
      children: [
        GoldHeader(
          title: zh ? '发布' : 'Post',
          subtitle: zh ? '发一条到校园墙' : 'Share something',
        ),
        Expanded(
          child: !widget.auth.isLoggedIn
              ? _needLogin(zh)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _titleCtrl,
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: zh ? '写个标题…' : 'Title…',
                            border: InputBorder.none,
                            counterStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFFB0B0B0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _contentCtrl,
                          maxLines: 8,
                          minLines: 6,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: zh
                                ? '说点什么…（支持换行）'
                                : 'Say something…',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: kBrandGold,
                            disabledBackgroundColor:
                                kBrandGold.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  zh ? '发布' : 'Publish',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        zh ? '以 ${widget.auth.user?.displayName ?? ''} 的身份发布'
                            : 'Posting as ${widget.auth.user?.displayName ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFA0A0A0)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _needLogin(bool zh) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 54, color: kBrandGold.withValues(alpha: 0.6)),
            const SizedBox(height: 18),
            Text(
              zh ? '还没登录' : 'Not signed in',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              zh ? '登录之后才能发帖和回复' : 'Sign in to post and reply',
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
