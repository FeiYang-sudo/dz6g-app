import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flarum_api.dart';

/// 登录状态。token 和用户信息存在手机本地，杀掉 App 再打开不用重新登录。
class AuthStore extends ChangeNotifier {
  static const String _kToken = 'flarum_token';
  static const String _kUser = 'flarum_user';

  final FlarumApi api;

  String? _token;
  Author? _user;

  AuthStore(this.api);

  String? get token => _token;
  Author? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;

  /// App 启动时调用：先把本地存的恢复出来（立刻可用），
  /// 再在后台悄悄验证 token 还有没有效，失效就自动退出登录。
  Future<void> restore() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kToken);
    final u = sp.getString(_kUser);
    if (t == null || u == null) return;

    try {
      _token = t;
      _user = Author.fromJson(jsonDecode(u) as Map<String, dynamic>);
      api.token = t;
      notifyListeners();
    } catch (_) {
      await logout();
      return;
    }

    // 后台校验，失败就当没登录（token 被撤销 / 换了密码 / 用户被删）
    unawaited(_verify());
  }

  Future<void> _verify() async {
    final u = _user;
    if (u == null) return;
    try {
      final fresh = await api.fetchUser(u.id);
      _user = fresh;
      await _save();
      notifyListeners();
    } on FlarumException catch (e) {
      // 网络不通不算登录失效；只有论坛明确说"没登录"才真的退出
      if (!e.isNetwork) {
        await logout();
      }
    } catch (_) {
      // 其它异常忽略，保留本地登录态
    }
  }

  /// 登录，失败会抛 FlarumException（message 可以直接显示给用户）
  Future<void> login(String identification, String password) async {
    final session = await api.login(identification.trim(), password);
    _token = session.token;
    _user = session.user;
    await _save();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    api.token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kUser);
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final t = _token;
    final u = _user;
    if (t == null || u == null) return;
    await sp.setString(_kToken, t);
    await sp.setString(
      _kUser,
      jsonEncode({
        'id': u.id,
        'attributes': {
          'username': u.username,
          'displayName': u.displayName,
          'avatarUrl': u.avatarUrl,
        },
      }),
    );
  }
}
