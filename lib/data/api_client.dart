import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The API said no, for good: a known business refusal (422 `refused`), such
/// as ASSIGNMENT_EXPIRED. The outbox PARKS the op, keeping its evidence, and
/// shows it with Retry / Dismiss. Never deleted without a person seeing it.
class ApiRefused implements Exception {
  ApiRefused(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'ApiRefused($code: $message)';
}

/// Anything else: retry later with backoff. [status] is null when there was
/// no response at all (offline, timeout, DNS), which stops the whole drain;
/// a status stops only the round it came from.
class ApiUnavailable implements Exception {
  ApiUnavailable(this.status, [this.detail]);
  final int? status;
  final Object? detail;

  /// Nothing will get through right now: no network, or no valid session.
  bool get stopsAll => status == null || status == 401 || status == 429;
  @override
  String toString() => 'ApiUnavailable(${status ?? 'no response'}: $detail)';
}

/// The refusal contract (plan, "The refusal contract"), as the phone reads it.
/// Pure, unit-tested: over-reading a refusal here destroys work, so a 422
/// counts only when the body says `refused: true`.
Object? classifyResponse(int status, String body) {
  if (status >= 200 && status < 300) {
    return body.isEmpty ? null : jsonDecode(body);
  }
  if (status == 422) {
    Object? j;
    try {
      j = jsonDecode(body);
    } on FormatException {
      j = null;
    }
    if (j is Map && j['refused'] == true) {
      throw ApiRefused('${j['code']}', '${j['message'] ?? ''}');
    }
  }
  throw ApiUnavailable(status, body.length > 200 ? body.substring(0, 200) : body);
}

/// HTTPS to the O House API: the only way this app reads or writes data.
/// Every call names its club (`X-Club`) and carries the user's token; writes
/// carry the `Idempotency-Key` fixed when the op was queued.
///
/// Hand-written on purpose (plan: no OpenAPI codegen). Fifteen endpoints.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.club,
    required this.token,
    required this.refreshSession,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String baseUrl;
  final String club;
  final String? Function() token;

  /// Called once on a 401. True when it produced a new token.
  final Future<bool> Function() refreshSession;
  final http.Client _http;

  static const _timeout = Duration(seconds: 60);

  Future<Object?> get(String path) =>
      _send(() async => http.Request('GET', _uri(path)));

  Future<Object?> post(String path, {Object? json, String? key}) =>
      _send(() async => _json('POST', path, json), key: key);

  Future<Object?> patch(String path, {Object? json}) =>
      _send(() async => _json('PATCH', path, json));

  /// Multipart: one [file] field plus text [fields].
  Future<Object?> upload(
    String path, {
    required File file,
    required Map<String, String> fields,
    required String key,
  }) => _send(() async {
    final r = http.MultipartRequest('POST', _uri(path))..fields.addAll(fields);
    r.files.add(await http.MultipartFile.fromPath('file', file.path));
    return r;
  }, key: key);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  http.Request _json(String method, String path, Object? json) {
    final r = http.Request(method, _uri(path));
    r.headers['content-type'] = 'application/json';
    r.body = jsonEncode(json ?? const {});
    return r;
  }

  /// Built afresh per attempt: a request body is a stream and can be sent once.
  Future<Object?> _send(
    Future<http.BaseRequest> Function() build, {
    String? key,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final req = await build();
      req.headers['x-club'] = club;
      final t = token();
      if (t != null) req.headers['authorization'] = 'Bearer $t';
      if (key != null) req.headers['idempotency-key'] = key;

      int status;
      String body;
      try {
        final res = await _http.send(req).timeout(_timeout);
        status = res.statusCode;
        body = await res.stream.bytesToString().timeout(_timeout);
      } on Exception catch (e) {
        // SocketException, TimeoutException, ClientException, a dropped
        // body: no answer. The op may or may not have landed, which is why
        // every write is safe to repeat.
        throw ApiUnavailable(null, e);
      }

      // Refresh once, then retry once. A refresh that fails for lack of
      // network is still retryable (plan); a dead refresh token signs the
      // user out, and the router takes them to sign-in with the queue kept.
      if (status == 401 && attempt == 0) {
        bool refreshed;
        try {
          refreshed = await refreshSession();
        } catch (e) {
          throw ApiUnavailable(401, e);
        }
        if (refreshed) continue;
      }
      return classifyResponse(status, body);
    }
  }
}
