import 'package:flutter_test/flutter_test.dart';
import 'package:openai_realtime_api/openai_realtime_api.dart';

void main() {
  group('EphemeralToken', () {
    test('parses GA client_secrets response shape', () {
      // Reviewer 3 caught: previous parser read data['client_secret']
      // ['value'] (pre-GA nested shape). GA returns flat:
      // { value, expires_at, session }
      final token = EphemeralToken.fromClientSecretsResponse({
        'value': 'ek_abc',
        'expires_at': 1735776000,
        'session': {'object': 'realtime.session'},
      });
      expect(token.value, 'ek_abc');
      expect(token.expiresAt.millisecondsSinceEpoch, 1735776000 * 1000);
      expect(token.isExpired, isTrue); // 2024-12-31, in the past
    });

    test('throws on malformed response', () {
      expect(
        () => EphemeralToken.fromClientSecretsResponse({'foo': 'bar'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('isExpired reflects expiresAt', () {
      final future = EphemeralToken(
        value: 'ek_a',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      final past = EphemeralToken(
        value: 'ek_b',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(future.isExpired, false);
      expect(past.isExpired, true);
    });
  });

  group('CachingEphemeralTokenProvider', () {
    test('caches a fresh token across calls', () async {
      var fetches = 0;
      final provider = CachingEphemeralTokenProvider(
        fetcher: () async {
          fetches++;
          return EphemeralToken(
            value: 'ek_$fetches',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
        },
      );

      final t1 = await provider.getToken();
      final t2 = await provider.getToken();
      expect(t1.value, 'ek_1');
      expect(t2.value, 'ek_1'); // cached
      expect(fetches, 1);
    });

    test('refreshes when nearing expiry', () async {
      var fetches = 0;
      final provider = CachingEphemeralTokenProvider(
        refreshBefore: const Duration(seconds: 10),
        fetcher: () async {
          fetches++;
          return EphemeralToken(
            value: 'ek_$fetches',
            // First fetch: about to expire (within refresh window).
            expiresAt:
                DateTime.now().add(const Duration(seconds: 5)),
          );
        },
      );
      await provider.getToken();
      // Second call must re-fetch because the cached token's
      // timeRemaining (≈5s) ≤ refreshBefore (10s).
      await provider.getToken();
      expect(fetches, 2);
    });

    test('de-duplicates concurrent in-flight fetches', () async {
      // Reviewer 3 caught: prior provider had no single-flight; N
      // concurrent getToken() calls fanned out to N upstream requests.
      var fetches = 0;
      final provider = CachingEphemeralTokenProvider(
        fetcher: () async {
          fetches++;
          await Future.delayed(const Duration(milliseconds: 20));
          return EphemeralToken(
            value: 'ek_$fetches',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );
        },
      );
      final results = await Future.wait([
        provider.getToken(),
        provider.getToken(),
        provider.getToken(),
      ]);
      expect(fetches, 1);
      expect(results.map((t) => t.value).toSet(), {'ek_1'});
    });
  });
}
