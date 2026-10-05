import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// ---------------------------------------------------------------------------
/// DoH（DNS over HTTPS）解析 + 「按 IP 连接、保持 SNI」的 HTTP 客户端
///
/// 解决什么问题：某些运营商/校园网会把 dz6g.ccwu.cc 的 DNS 解析结果污染成
/// 0.0.0.0（黑洞地址），于是浏览器和 App 都连不上，但换个网络（如移动数据）
/// 又正常。这里不再信任系统 DNS，改用加密 DNS（DoH）拿真实 IP，然后
/// 直接连那个 IP，但 TLS 的 SNI 与证书校验仍然按域名走。
///
/// 实测依据（2026-10-01）：check-host 国内节点 ch2 解析本域名为 0.0.0.0，
/// 而 dns.alidns.com / doh.pub / doh.360.cn 三个 DoH 端点均可正常返回真实 IP。
/// ---------------------------------------------------------------------------

/// 国内可用的 DoH 端点（JSON 接口，与 Google/Cloudflare 的格式兼容）
const List<String> kDohEndpoints = <String>[
  'https://dns.alidns.com/resolve', // 阿里
  'https://doh.pub/dns-query', // 腾讯 DNSPod
  'https://doh.360.cn/resolve', // 360
];

/// 只有这些域名走 DoH 解析（其余域名仍用系统解析，避免无谓开销与递归）
const Set<String> kDohHosts = <String>{
  'dz6g.ccwu.cc',
  'auth.dz6g.ccwu.cc',
};

class _CacheEntry {
  _CacheEntry(this.ips, this.at);
  final List<String> ips;
  final DateTime at;
}

final Map<String, _CacheEntry> _dohCache = <String, _CacheEntry>{};

/// 查 DoH 用的普通客户端。注意：它请求的域名（dns.alidns.com 等）不在
/// kDohHosts 里，所以不会触发递归解析。
final HttpClient _plainHttpClient = HttpClient()
  ..connectionTimeout = const Duration(seconds: 8);

/// 最近一次 DoH 解析结果，供诊断信息使用，例如 "dz6g.ccwu.cc=104.21.88.222"
String lastDohResult = '';

/// 用 DoH 解析域名 → 真实 IPv4 列表；失败返回空列表（调用方回落到系统解析）
Future<List<String>> dohResolve(String host, {bool force = false}) async {
  final hit = _dohCache[host];
  if (!force &&
      hit != null &&
      DateTime.now().difference(hit.at) < const Duration(minutes: 5)) {
    return hit.ips;
  }
  for (final ep in kDohEndpoints) {
    try {
      final req = await _plainHttpClient
          .getUrl(Uri.parse('$ep?name=$host&type=A'))
          .timeout(const Duration(seconds: 6));
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) continue;
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final answers = (data is Map ? data['Answer'] : null) as List? ?? const [];
      final ips = <String>[];
      for (final a in answers) {
        if (a is Map && a['type'] == 1 && a['data'] is String) {
          final ip = a['data'] as String;
          // 过滤掉黑洞地址，避免"解析成功但连不上"
          if (ip != '0.0.0.0' && InternetAddress.tryParse(ip) != null) {
            ips.add(ip);
          }
        }
      }
      if (ips.isNotEmpty) {
        _dohCache[host] = _CacheEntry(ips, DateTime.now());
        lastDohResult = '$host=${ips.join("/")}';
        return ips;
      }
    } catch (_) {
      // 这个端点不通，试下一个
    }
  }
  return const <String>[];
}

/// 把 DoH 装进全局：App 里所有 HttpClient（含 http 包、Image.network 加载的头像）
/// 都会走这套解析。放在 main() 里调一次。
void installDohOverrides() {
  HttpOverrides.global = DohHttpOverrides();
}

class DohHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 10);
    client.connectionFactory = _connectionFactory;
    return client;
  }
}

/// 核心：自己选 IP 建 socket，TLS 仍然用域名做 SNI 和证书校验
Future<ConnectionTask<Socket>> _connectionFactory(
  Uri uri,
  String? proxyHost,
  int? proxyPort,
) async {
  Socket raw;
  final useDoh = proxyHost == null && kDohHosts.contains(uri.host);
  var dialHost = uri.host;

  if (useDoh) {
    final ips = await dohResolve(uri.host);
    if (ips.isNotEmpty) dialHost = ips.first;
  }
  if (proxyHost != null) {
    raw = await Socket.connect(proxyHost, proxyPort ?? 8080,
        timeout: const Duration(seconds: 8));
  } else {
    raw = await Socket.connect(dialHost, uri.port,
        timeout: const Duration(seconds: 10));
  }

  if (uri.scheme == 'https') {
    // host 传域名：SNI 正确、证书按域名校验，不会因为连的是 IP 而失败
    final secure = await SecureSocket.secure(raw, host: uri.host);
    return ConnectionTask.fromSocket(Future<Socket>.value(secure), () {});
  }
  return ConnectionTask.fromSocket(Future<Socket>.value(raw), () {});
}
