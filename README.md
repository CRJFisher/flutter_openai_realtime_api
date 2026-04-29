# flutter_openai_realtime_api

[![pub package](https://img.shields.io/pub/v/flutter_openai_realtime_api.svg)](https://pub.dev/packages/flutter_openai_realtime_api)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/crjfisher/flutter_openai_realtime_api/actions/workflows/ci.yml/badge.svg)](https://github.com/crjfisher/flutter_openai_realtime_api/actions/workflows/ci.yml)

Flutter client for the OpenAI Realtime GA API. Targets `gpt-realtime` over
WebRTC for low-latency voice conversations and over WebSocket for
server-side or text-only use.

Full API reference: <https://pub.dev/documentation/flutter_openai_realtime_api/latest/>

## Install

```sh
flutter pub add flutter_openai_realtime_api
```

Or add manually:

```yaml
dependencies:
  flutter_openai_realtime_api: ^0.3.0
```

## Quick start

A Flutter client connecting via WebRTC needs an ephemeral token from your
backend (see Backend setup, below). With a token provider in hand:

```dart
import 'package:flutter_openai_realtime_api/flutter_openai_realtime_api.dart';

final client = RealtimeClient.webRtc(RealtimeConfig(
  tokenProvider: myTokenProvider,
  voice: Voice.alloy,
  instructions: 'You are a helpful, concise assistant.',
  turnDetection: const ServerVad.quick(),
));

client.events.listen((event) {
  if (event is InputAudioTranscriptionCompleted) {
    print('You said: ${event.transcript}');
  } else if (event is ResponseAudioTranscriptDone) {
    print('AI said:  ${event.transcript}');
  }
});

await client.connect();
// ... talk normally; server VAD turns over automatically ...
await client.dispose();
```

The same client supports text only:

```dart
await client.sendMessage('Summarise the conversation so far.');
```

### WebSocket transport

For server-side Dart (Cloud Functions, Shelf, CLIs) or text-only Flutter
clients, use the WebSocket transport. Browsers cannot set the
`Authorization` header on a WebSocket upgrade, so this transport is not
appropriate for Flutter Web.

```dart
final client = RealtimeClient.webSocket(RealtimeConfig(
  apiKey: openAiKey, // long-lived sk-… key, server-side only
));

await client.connect();
await client.sendMessage('Generate a haiku about caching.');
await client.dispose();
```

Choose WebRTC for voice from a Flutter app; choose WebSocket for
server-side workloads or when you only need text round-trips.

## Backend setup

Long-lived OpenAI keys (`sk-…`) must never ship in a Flutter binary —
anyone who unpacks the app gets the key. The Realtime API solves this
with **ephemeral client secrets** (`ek_…`): short-lived strings your
backend mints on behalf of an authenticated user, used as the
`Authorization: Bearer` token only for the SDP exchange.

```
Flutter client          Your backend             OpenAI
     |                       |                      |
     |  POST /realtime/      |                      |
     |    token         --->|                      |
     |  (Firebase ID token)  |                      |
     |                       |  POST /v1/realtime/  |
     |                       |   client_secrets     |
     |                       |   Bearer sk-...  --->|
     |                       | <--- {value: ek_...} |
     | <-- {token: ek_...,   |                      |
     |      expiresAt: ...}  |                      |
     |                       |                      |
     |  POST /v1/realtime/calls (Bearer ek_...) --->  (SDP exchange)
```

### The OpenAI endpoint

```
POST https://api.openai.com/v1/realtime/client_secrets
Authorization: Bearer <YOUR_OPENAI_API_KEY>
Content-Type:  application/json
```

Request body:

```json
{
  "expires_after": { "anchor": "created_at", "seconds": 120 },
  "session": {
    "type": "realtime",
    "model": "gpt-realtime"
  }
}
```

Response body:

```json
{
  "value": "ek_68af296e8e408191a1120ab6383263c2",
  "expires_at": 1735776000,
  "session": { "id": "sess_…", "...": "fully-resolved server view" }
}
```

`expires_after.seconds` accepts 10–7200 (default 600). Keep it short
(60–180): the token only needs to live long enough to complete the SDP
exchange. Once the WebRTC connection is up, the call runs to OpenAI's
hard 30-minute server cap regardless of token TTL.

### Firebase Cloud Functions example

If your app already uses Firebase Auth, this is the most idiomatic
backend.

```ts
// functions/src/realtimeToken.ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { logger } from "firebase-functions/v2";

if (!getApps().length) initializeApp();

// firebase functions:secrets:set OPENAI_API_KEY
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

export const realtimeToken = onCall(
  {
    region: "us-central1",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;

    // Per-user rate limit (1 mint / 5s).
    const db = getFirestore();
    const ref = db.doc(`rateLimits/realtimeToken/${uid}/state`);
    const now = Date.now();
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const last = (snap.data()?.lastMintMs as number | undefined) ?? 0;
      if (now - last < 5_000) {
        throw new HttpsError("resource-exhausted", "Slow down.");
      }
      tx.set(ref, { lastMintMs: now, updatedAt: FieldValue.serverTimestamp() });
    });

    const r = await fetch("https://api.openai.com/v1/realtime/client_secrets", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        expires_after: { anchor: "created_at", seconds: 120 },
        session: {
          type: "realtime",
          model: "gpt-realtime",
          audio: { output: { voice: "alloy" } },
        },
      }),
    });

    if (!r.ok) {
      logger.error("openai_mint_failed", {
        status: r.status,
        body: await r.text(),
      });
      throw new HttpsError("unavailable", "Upstream error.");
    }

    const data = (await r.json()) as { value: string; expires_at: number };
    logger.info("minted", { uid, expiresAt: data.expires_at });
    return { token: data.value, expiresAt: data.expires_at };
  },
);
```

Calling it from Flutter:

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_openai_realtime_api/flutter_openai_realtime_api.dart';

class FirebaseTokenProvider implements EphemeralTokenProvider {
  @override
  Future<EphemeralToken> getToken() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('realtimeToken')
        .call();
    return EphemeralToken(
      value: result.data['token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (result.data['expiresAt'] as int) * 1000,
      ),
    );
  }
}

final provider = CachingEphemeralTokenProvider(
  fetcher: FirebaseTokenProvider().getToken,
);
final client = RealtimeClient.webRtc(RealtimeConfig(
  tokenProvider: provider,
  // ...
));
```

`CachingEphemeralTokenProvider` reuses the cached token until it is
within 10 s of expiry, and de-duplicates concurrent in-flight fetches.

`defineSecret` keeps the OpenAI key in Google Secret Manager so it
never appears in source control or build logs. `enforceAppCheck: true`
restricts the function to your real app binaries.

### Express / FastAPI / other backends

The contract is identical: authenticate the user, call
`POST /v1/realtime/client_secrets`, return `{token, expiresAt}` to the
client. Any HTTP server works.

### CORS for Flutter Web

Native HTTP requests are not subject to CORS. Flutter Web is. For Web
clients:

- Set `Access-Control-Allow-Origin` to your exact app origin.
- Handle the `OPTIONS` preflight for `POST` with `Authorization` and
  `Content-Type` headers. Firebase callables handle this automatically;
  for raw HTTP functions enable the `cors` option.
- The SDP exchange (`POST /v1/realtime/calls`) goes directly from the
  browser to OpenAI — there is no need to proxy it through your backend.

### Production checklist

- [ ] OpenAI key stored in a real secret manager.
- [ ] Token endpoint requires an authenticated user.
- [ ] Per-user and per-IP rate limits.
- [ ] Per-user daily/monthly minute quota.
- [ ] `expires_after.seconds` set to 60–180.
- [ ] CORS configured for your Flutter Web origin (if applicable).
- [ ] App Check (or equivalent attestation).
- [ ] Server-side allowlist for `session.*` fields the client may set.
- [ ] No `sk-…` value in the client repo or build artifacts.

## Platform setup

### iOS

`ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used for voice conversations with the AI assistant.</string>
```

For background audio:

```xml
<key>UIBackgroundModes</key>
<array><string>audio</string><string>voip</string></array>
```

### Android

`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

`android/app/build.gradle`:

```gradle
android { defaultConfig { minSdkVersion 21 } }   // flutter_webrtc minimum
```

Use `permission_handler` (or similar) at runtime to request microphone
permission before `client.connect()`.

### Web

Must be served over HTTPS (or `localhost`). Browsers will not autoplay
audio until the page has had a user gesture, so gate `connect()`
behind a button tap.

The package does not auto-attach the remote audio track to a DOM
`<audio>` element on Web — Flutter's rendering layer cannot reach the
browser's audio output without help. In your app, listen for the
`onTrack` event on the underlying `RTCPeerConnection` (exposed via
`flutter_webrtc`) and route the remote `MediaStream` to an `<audio>`
element through `flutter_webrtc`'s renderer or a small JS interop call.
Native platforms wire this automatically.

### macOS

`macos/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used for voice conversations.</string>
```

Apply the same two keys to **both** `macos/Runner/DebugProfile.entitlements`
**and** `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

`network.client` is required for the outbound HTTPS SDP exchange; the
hardened runtime blocks it otherwise.

## Voice and model selection

| Field   | Default          | Choices                                                                                                               |
| ------- | ---------------- | --------------------------------------------------------------------------------------------------------------------- |
| `model` | `gpt-realtime`   | `gpt-realtime`, `gpt-realtime-mini`, `gpt-realtime-2025-08-28`                                                        |
| `voice` | (server default) | `alloy`, `ash`, `ballad`, `coral`, `echo`, `sage`, `shimmer`, `verse`, `marin` (gpt-realtime), `cedar` (gpt-realtime) |

`marin` and `cedar` work only with `gpt-realtime`; the other eight work
with every current model.

## Echo cancellation on Android

Android's `getUserMedia` echo cancellation does not reliably stop
loudspeaker audio from being picked up by the mic when the user is not
wearing headphones. `MuteStrategy.aggressive` mitigates this by
replacing the outbound audio track with `null` while the assistant is
speaking, which stops RTP entirely. `MuteStrategy.auto` (the default)
uses `aggressive` on Android and `standard` everywhere else.

## Interrupting the assistant

To barge in mid-utterance, send the three-step interruption sequence:

```dart
await client.cancelResponse();           // 1. stop generation
await client.clearOutputAudioBuffer();   // 2. flush server-side audio queue (WebRTC only)
await client.truncateConversation(       // 3. reconcile history with what the user actually heard
  itemId: itemId,
  contentIndex: 0,
  audioEndMs: playbackPositionMs,
);
```

When `turn_detection.interrupt_response` is `true` (the default for
both `ServerVad` and `SemanticVad`), the server runs the equivalent
sequence automatically when it detects new user speech. The manual API
is for cases where your UI surfaces an explicit interrupt control.

## Function calling

```dart
final tool = Tool(
  name: 'get_weather',
  description: 'Get current weather for a city.',
  parameters: const {
    'type': 'object',
    'properties': {
      'city': {'type': 'string'},
    },
    'required': ['city'],
  },
);

final client = RealtimeClient.webRtc(RealtimeConfig(
  tokenProvider: myTokenProvider,
  tools: [tool],
));

client.events.listen((event) async {
  if (event is ResponseFunctionCallArgumentsDone) {
    final args = jsonDecode(event.arguments) as Map<String, dynamic>;
    final result = await getWeather(args['city'] as String);

    await client.createConversationItem(
      ConversationItem.functionCallOutput(
        callId: event.callId,
        output: jsonEncode(result),
      ),
    );
    // The server does NOT auto-respond after a tool result. You must
    // explicitly ask it for the next turn.
    await client.createResponse();
  }
});
```

## Logging

The package emits via `package:logging`. Attach a console listener at
app start:

```dart
RealtimeLogging.enableConsoleOutput();
```

## License

MIT. See [LICENSE](LICENSE).
