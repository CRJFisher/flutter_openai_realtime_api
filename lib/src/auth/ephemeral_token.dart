import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../internal/protocol.dart';

/// A short-lived client secret minted by your backend. Used as the
/// `Bearer` token for the WebRTC SDP exchange.
class EphemeralToken {
  /// The token value, format `ek_…`.
  final String value;

  /// Server-side expiry. Mint a new token if you would otherwise use this
  /// one past [expiresAt].
  final DateTime expiresAt;

  const EphemeralToken({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining {
    final r = expiresAt.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// Parses the GA `/v1/realtime/client_secrets` response.
  factory EphemeralToken.fromClientSecretsResponse(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final expiresAt = json['expires_at'];
    if (value == null || expiresAt == null) {
      throw FormatException(
        'Unexpected client_secrets response: $json',
      );
    }
    return EphemeralToken(
      value: value,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (expiresAt as num).toInt() * 1000,
      ),
    );
  }
}

/// Mints or fetches a fresh [EphemeralToken] when the client needs one.
///
/// Implement this against your own backend. Your backend calls
/// `POST https://api.openai.com/v1/realtime/client_secrets` with the
/// long-lived OpenAI API key and returns the resulting `value` to the
/// client. See the README for a Firebase Cloud Functions example.
abstract class EphemeralTokenProvider {
  /// Returns a token whose [EphemeralToken.expiresAt] is in the future.
  Future<EphemeralToken> getToken();
}

/// Caches a token until shortly before it expires, then re-mints by
/// calling [fetcher]. De-duplicates concurrent in-flight fetches.
class CachingEphemeralTokenProvider implements EphemeralTokenProvider {
  /// Mints a fresh token. Typically wraps an HTTP call to your backend.
  final Future<EphemeralToken> Function() fetcher;

  /// Refresh the cached token this far in advance of expiry.
  final Duration refreshBefore;

  EphemeralToken? _cached;
  Future<EphemeralToken>? _inFlight;

  CachingEphemeralTokenProvider({
    required this.fetcher,
    this.refreshBefore = const Duration(seconds: 10),
  });

  @override
  Future<EphemeralToken> getToken() {
    final existing = _cached;
    if (existing != null && existing.timeRemaining > refreshBefore) {
      return Future.value(existing);
    }
    return _inFlight ??= () async {
      try {
        final fresh = await fetcher();
        _cached = fresh;
        return fresh;
      } finally {
        _inFlight = null;
      }
    }();
  }
}

/// Server-side helper that mints a token directly against the OpenAI API.
///
/// **Do not use this from a Flutter app shipped to users** — it requires
/// the long-lived `sk-…` key. It is included here for backend
/// integrations that happen to be written in Dart (e.g. a Dart Shelf or
/// Cloud Functions backend).
class OpenAIClientSecretMinter {
  final String apiKey;
  final String baseUrl;
  final http.Client _http;
  final bool _ownsHttp;

  OpenAIClientSecretMinter({
    required this.apiKey,
    this.baseUrl = Protocol.apiBaseUrl,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  /// Mint a token. [sessionConfig] is forwarded as the `session` field;
  /// [expiresInSeconds] sets `expires_after.seconds` (10–7200, default 600).
  Future<EphemeralToken> mint({
    Map<String, dynamic>? sessionConfig,
    int? expiresInSeconds,
  }) async {
    final body = <String, dynamic>{
      if (sessionConfig != null) 'session': sessionConfig,
      if (expiresInSeconds != null)
        'expires_after': {'anchor': 'created_at', 'seconds': expiresInSeconds},
    };

    final resp = await _http.post(
      Uri.parse('$baseUrl${Protocol.clientSecretsPath}'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return EphemeralToken.fromClientSecretsResponse(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw EphemeralTokenException(
      'client_secrets request failed: '
      '${resp.statusCode} ${resp.reasonPhrase}',
    );
  }

  void dispose() {
    if (_ownsHttp) _http.close();
  }
}

/// Thrown when an [EphemeralTokenProvider] cannot mint a token (HTTP error,
/// malformed response, missing API key, etc.).
class EphemeralTokenException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;
  const EphemeralTokenException(this.message);
  @override
  String toString() => 'EphemeralTokenException: $message';
}
