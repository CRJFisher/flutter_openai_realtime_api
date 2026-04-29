import '../models/conversation_item.dart';
import '../models/events.dart';
import 'protocol.dart';

/// Parses raw server JSON payloads into typed [RealtimeEvent]s.
///
/// Handles both GA event names (`response.output_text.delta`) and pre-GA
/// aliases (`response.text.delta`) that older `gpt-4o-realtime-preview-*`
/// snapshots still emit. Unknown event types are returned as
/// [UnknownRealtimeEvent] so callers can introspect them rather than
/// silently dropping unfamiliar messages.
class EventParser {
  static int _seq = 0;
  static String _genId() {
    _seq++;
    return 'client_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  static String _eventId(Map<String, dynamic> json) =>
      (json['event_id'] as String?) ?? _genId();

  static int? _intOf(Object? v) => v is num ? v.toInt() : null;

  static RealtimeEvent parse(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final eventId = _eventId(json);
    final ts = DateTime.now();

    switch (type) {
      // ----- Session -----
      case Protocol.sessionCreated:
        final session = (json['session'] as Map<String, dynamic>?) ?? const {};
        return SessionCreated(
          eventId: eventId,
          timestamp: ts,
          sessionId: (session['id'] as String?) ?? '',
          session: session,
        );
      case Protocol.sessionUpdated:
        final session = (json['session'] as Map<String, dynamic>?) ?? const {};
        return SessionUpdated(
          eventId: eventId,
          timestamp: ts,
          sessionId: (session['id'] as String?) ?? '',
          session: session,
        );

      // ----- Conversation -----
      case Protocol.conversationCreated:
        return ConversationCreated(
          eventId: eventId,
          timestamp: ts,
          conversationId:
              (json['conversation']?['id'] as String?) ?? '',
        );
      case Protocol.conversationItemCreated:
        return ConversationItemCreated(
          eventId: eventId,
          timestamp: ts,
          previousItemId: json['previous_item_id'] as String?,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.conversationItemAdded:
        return ConversationItemAdded(
          eventId: eventId,
          timestamp: ts,
          previousItemId: json['previous_item_id'] as String?,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.conversationItemDone:
        return ConversationItemDone(
          eventId: eventId,
          timestamp: ts,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.conversationItemRetrieved:
        return ConversationItemRetrieved(
          eventId: eventId,
          timestamp: ts,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.conversationItemDeleted:
        return ConversationItemDeleted(
          eventId: eventId,
          timestamp: ts,
          itemId: (json['item_id'] as String?) ?? '',
        );
      case Protocol.conversationItemTruncated:
        return ConversationItemTruncated(
          eventId: eventId,
          timestamp: ts,
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          audioEndMs: _intOf(json['audio_end_ms']) ?? 0,
        );

      // ----- Input audio transcription -----
      case Protocol.inputAudioTranscriptionDelta:
        return InputAudioTranscriptionDelta(
          eventId: eventId,
          timestamp: ts,
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          delta: (json['delta'] as String?) ?? '',
        );
      case Protocol.inputAudioTranscriptionCompleted:
        return InputAudioTranscriptionCompleted(
          eventId: eventId,
          timestamp: ts,
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          transcript: (json['transcript'] as String?) ?? '',
          usage: json['usage'] as Map<String, dynamic>?,
        );
      case Protocol.inputAudioTranscriptionFailed:
        return InputAudioTranscriptionFailed(
          eventId: eventId,
          timestamp: ts,
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          error:
              (json['error'] as Map<String, dynamic>?) ?? const {},
        );

      // ----- Input audio buffer -----
      case Protocol.inputAudioBufferCommitted:
        return InputAudioBufferCommitted(
          eventId: eventId,
          timestamp: ts,
          previousItemId: json['previous_item_id'] as String?,
          itemId: json['item_id'] as String?,
        );
      case Protocol.inputAudioBufferCleared:
        return InputAudioBufferCleared(eventId: eventId, timestamp: ts);
      case Protocol.inputAudioBufferSpeechStarted:
        return InputAudioBufferSpeechStarted(
          eventId: eventId,
          timestamp: ts,
          audioStartMs: _intOf(json['audio_start_ms']),
          itemId: json['item_id'] as String?,
        );
      case Protocol.inputAudioBufferSpeechStopped:
        return InputAudioBufferSpeechStopped(
          eventId: eventId,
          timestamp: ts,
          audioEndMs: _intOf(json['audio_end_ms']),
          itemId: json['item_id'] as String?,
        );
      case Protocol.inputAudioBufferTimeoutTriggered:
        return InputAudioBufferTimeoutTriggered(
          eventId: eventId,
          timestamp: ts,
          audioStartMs: _intOf(json['audio_start_ms']) ?? 0,
          audioEndMs: _intOf(json['audio_end_ms']) ?? 0,
          itemId: (json['item_id'] as String?) ?? '',
        );

      // ----- Output audio buffer (WebRTC only) -----
      case Protocol.outputAudioBufferStarted:
        return OutputAudioBufferStarted(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
        );
      case Protocol.outputAudioBufferStopped:
        return OutputAudioBufferStopped(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
        );
      case Protocol.outputAudioBufferCleared:
        return OutputAudioBufferCleared(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
        );

      // ----- Response lifecycle -----
      case Protocol.responseCreated:
        final resp = (json['response'] as Map<String, dynamic>?) ?? const {};
        return ResponseCreated(
          eventId: eventId,
          timestamp: ts,
          responseId: (resp['id'] as String?) ?? '',
          response: resp,
        );
      case Protocol.responseDone:
        final resp = (json['response'] as Map<String, dynamic>?) ?? const {};
        final usageJson = resp['usage'] as Map<String, dynamic>?;
        return ResponseDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (resp['id'] as String?) ?? '',
          response: resp,
          usage:
              usageJson != null ? RealtimeUsage.fromJson(usageJson) : null,
          status: resp['status'] as String?,
        );
      case Protocol.responseOutputItemAdded:
        return ResponseOutputItemAdded(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          outputIndex: _intOf(json['output_index']) ?? 0,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.responseOutputItemDone:
        return ResponseOutputItemDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          outputIndex: _intOf(json['output_index']) ?? 0,
          item: ConversationItem.fromJson(
            (json['item'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.responseContentPartAdded:
        return ResponseContentPartAdded(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          outputIndex: _intOf(json['output_index']) ?? 0,
          contentIndex: _intOf(json['content_index']) ?? 0,
          part: ContentPart.fromJson(
            (json['part'] as Map<String, dynamic>?) ?? const {},
          ),
        );
      case Protocol.responseContentPartDone:
        return ResponseContentPartDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          outputIndex: _intOf(json['output_index']) ?? 0,
          contentIndex: _intOf(json['content_index']) ?? 0,
          part: ContentPart.fromJson(
            (json['part'] as Map<String, dynamic>?) ?? const {},
          ),
        );

      // ----- Response text (GA + pre-GA aliases) -----
      case Protocol.responseOutputTextDelta:
      case Protocol.responseTextDeltaPreGA:
        return ResponseTextDelta(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          delta: (json['delta'] as String?) ?? '',
        );
      case Protocol.responseOutputTextDone:
      case Protocol.responseTextDonePreGA:
        return ResponseTextDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          text: (json['text'] as String?) ?? '',
        );

      // ----- Response audio (GA + pre-GA aliases) -----
      case Protocol.responseOutputAudioDelta:
      case Protocol.responseAudioDeltaPreGA:
        return ResponseAudioDelta(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          delta: (json['delta'] as String?) ?? '',
        );
      case Protocol.responseOutputAudioDone:
      case Protocol.responseAudioDonePreGA:
        return ResponseAudioDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
        );

      // ----- Response audio transcript (GA + pre-GA aliases) -----
      case Protocol.responseOutputAudioTranscriptDelta:
      case Protocol.responseAudioTranscriptDeltaPreGA:
        return ResponseAudioTranscriptDelta(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          delta: (json['delta'] as String?) ?? '',
        );
      case Protocol.responseOutputAudioTranscriptDone:
      case Protocol.responseAudioTranscriptDonePreGA:
        return ResponseAudioTranscriptDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          contentIndex: _intOf(json['content_index']) ?? 0,
          transcript: (json['transcript'] as String?) ?? '',
        );

      // ----- Function calls -----
      case Protocol.responseFunctionCallArgumentsDelta:
        return ResponseFunctionCallArgumentsDelta(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          callId: (json['call_id'] as String?) ?? '',
          delta: (json['delta'] as String?) ?? '',
        );
      case Protocol.responseFunctionCallArgumentsDone:
        return ResponseFunctionCallArgumentsDone(
          eventId: eventId,
          timestamp: ts,
          responseId: (json['response_id'] as String?) ?? '',
          itemId: (json['item_id'] as String?) ?? '',
          callId: (json['call_id'] as String?) ?? '',
          arguments: (json['arguments'] as String?) ?? '',
        );

      // ----- Rate limits -----
      case Protocol.rateLimitsUpdated:
        final list =
            (json['rate_limits'] as List<dynamic>?) ?? const <dynamic>[];
        return RateLimitsUpdated(
          eventId: eventId,
          timestamp: ts,
          rateLimits: list.map((e) {
            final m = e as Map<String, dynamic>;
            return RateLimit(
              name: (m['name'] as String?) ?? '',
              limit: _intOf(m['limit']) ?? 0,
              remaining: _intOf(m['remaining']) ?? 0,
              resetSeconds: (m['reset_seconds'] as num?)?.toDouble() ?? 0.0,
            );
          }).toList(),
        );

      // ----- Error -----
      case Protocol.error:
        final err =
            (json['error'] as Map<String, dynamic>?) ?? const {};
        return ErrorEvent(
          eventId: eventId,
          timestamp: ts,
          type: err['type'] as String?,
          code: err['code'] as String?,
          message: (err['message'] as String?) ?? '',
          param: err['param'] as String?,
          errorEventId: err['event_id'] as String?,
        );

      default:
        return UnknownRealtimeEvent(
          eventId: eventId,
          timestamp: ts,
          type: type,
          raw: json,
        );
    }
  }
}
