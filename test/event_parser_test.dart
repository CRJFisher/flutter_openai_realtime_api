import 'package:flutter_test/flutter_test.dart';
import 'package:openai_realtime_api/openai_realtime_api.dart';
import 'package:openai_realtime_api/src/internal/event_parser.dart';

void main() {
  group('EventParser', () {
    test('parses session.created', () {
      final event = EventParser.parse({
        'type': 'session.created',
        'event_id': 'event_001',
        'session': {'id': 'sess_abc', 'object': 'realtime.session'},
      }) as SessionCreated;
      expect(event.eventId, 'event_001');
      expect(event.sessionId, 'sess_abc');
    });

    test('parses GA response.output_text.delta', () {
      final event = EventParser.parse({
        'type': 'response.output_text.delta',
        'event_id': 'event_002',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'output_index': 0,
        'content_index': 0,
        'delta': 'Hello',
      }) as ResponseTextDelta;
      expect(event.delta, 'Hello');
      expect(event.itemId, 'item_1');
    });

    test('parses pre-GA response.text.delta as ResponseTextDelta', () {
      // Older `gpt-4o-realtime-preview-*` snapshots emit the unprefixed
      // event name. The parser canonicalizes both to the same Dart class.
      final event = EventParser.parse({
        'type': 'response.text.delta',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'content_index': 0,
        'delta': 'Hi',
      });
      expect(event, isA<ResponseTextDelta>());
      expect((event as ResponseTextDelta).delta, 'Hi');
    });

    test('parses pre-GA response.audio.delta', () {
      final event = EventParser.parse({
        'type': 'response.audio.delta',
        'response_id': 'resp_1',
        'item_id': 'item_1',
        'content_index': 0,
        'delta': 'base64audio==',
      });
      expect(event, isA<ResponseAudioDelta>());
      expect((event as ResponseAudioDelta).delta, 'base64audio==');
    });

    test('parses response.done with full usage', () {
      final event = EventParser.parse({
        'type': 'response.done',
        'response': {
          'id': 'resp_1',
          'status': 'completed',
          'usage': {
            'total_tokens': 100,
            'input_tokens': 60,
            'output_tokens': 40,
            'input_token_details': {
              'cached_tokens': 10,
              'text_tokens': 30,
              'audio_tokens': 20,
            },
            'output_token_details': {
              'text_tokens': 25,
              'audio_tokens': 15,
            },
          },
        },
      }) as ResponseDone;
      expect(event.status, 'completed');
      expect(event.usage?.totalTokens, 100);
      expect(event.usage?.cachedTokens, 10);
      expect(event.usage?.outputAudioTokens, 15);
    });

    test('parses input_audio_buffer.speech_started with int audioStartMs', () {
      // Reviewer 4 caught: parser used to type these as String?, but the
      // wire format is int. Regression-pin the int handling.
      final event = EventParser.parse({
        'type': 'input_audio_buffer.speech_started',
        'audio_start_ms': 1234,
        'item_id': 'item_1',
      }) as InputAudioBufferSpeechStarted;
      expect(event.audioStartMs, 1234);
    });

    test('parses rate_limits.updated with integer reset_seconds', () {
      // Reviewer 4 caught: `as double?` cast crashed on integer values.
      final event = EventParser.parse({
        'type': 'rate_limits.updated',
        'rate_limits': [
          {
            'name': 'requests',
            'limit': 1000,
            'remaining': 999,
            'reset_seconds': 60, // integer on the wire
          },
          {
            'name': 'tokens',
            'limit': 50000,
            'remaining': 49995,
            'reset_seconds': 60.5, // sometimes a float
          },
        ],
      }) as RateLimitsUpdated;
      expect(event.rateLimits, hasLength(2));
      expect(event.rateLimits.first.name, 'requests');
      expect(event.rateLimits.first.resetSeconds, 60.0);
      expect(event.rateLimits[1].resetSeconds, 60.5);
    });

    test('parses error event with absent type/code', () {
      // Reviewer 4 caught: previous parser fabricated 'unknown' defaults
      // for type and code, losing the absent-vs-literal distinction.
      final event = EventParser.parse({
        'type': 'error',
        'error': {'message': 'Invalid request'},
      }) as ErrorEvent;
      expect(event.type, isNull);
      expect(event.code, isNull);
      expect(event.message, 'Invalid request');
    });

    test('parses output_audio_buffer.started (WebRTC only)', () {
      final event = EventParser.parse({
        'type': 'output_audio_buffer.started',
        'response_id': 'resp_1',
      }) as OutputAudioBufferStarted;
      expect(event.responseId, 'resp_1');
    });

    test('returns UnknownRealtimeEvent for unknown types', () {
      // Reviewer 4 caught: unknown events used to return null, silently
      // dropping forward-compat events. They now surface typed.
      final event = EventParser.parse({
        'type': 'some.future.event',
        'event_id': 'event_999',
        'foo': 'bar',
      });
      expect(event, isA<UnknownRealtimeEvent>());
      final unk = event as UnknownRealtimeEvent;
      expect(unk.type, 'some.future.event');
      expect(unk.raw['foo'], 'bar');
    });
  });
}
