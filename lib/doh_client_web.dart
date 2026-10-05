/// Web 版占位实现：浏览器不支持直接建 socket / 自定义 DNS 解析，
/// 也拿不到 dart:io 的 HttpClient，所以这里把 DoH 全套降级为「用系统解析」。
///
/// 为什么要有这个文件：`doh_client.dart` 里的 `installDohOverrides()` 与
/// `dohResolve()` 在手机/桌面端用 dart:io 实现（绕开运营商 DNS 污染），
/// 但 `dart:io` 在 Web 上不可用 —— 不加这个条件实现，`flutter build web` 会直接编译失败。
/// 手机端行为完全不受影响（走的仍是 doh_client_io.dart）。
library;

/// 最近一次 DoH 解析结果（Web 端恒为空）
String lastDohResult = '';

/// Web 端不做 DoH，返回空列表 —— 调用方会自动回落到浏览器自身的解析
Future<List<String>> dohResolve(String host, {bool force = false}) async => <String>[];

/// Web 端无需覆盖 HttpClient
void installDohOverrides() {}
