/// DoH 客户端的条件实现：
/// - 手机 / 桌面（有 dart:io）→ doh_client_io.dart（真 DoH，绕开运营商 DNS 污染）
/// - Web（无 dart:io）        → doh_client_web.dart（空实现，交给浏览器解析）
///
/// 这样同一份代码既能编 APK，也能 `flutter build web`（用于预览/截图）。
export 'doh_client_web.dart' if (dart.library.io) 'doh_client_io.dart';
