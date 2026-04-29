import 'conversation_item.dart';

/// Base class for every event emitted by [RealtimeClient.events].
///
/// Subclasses fall into one of: [SessionEvent], [ConversationEvent],
/// [ResponseEvent], [AudioEvent], [RateLimitsUpdated], [ErrorEvent],
/// [ConnectionEvent], [UnknownRealtimeEvent].
abstract class RealtimeEvent {
  /// `event_id` from the server, or a client-generated id for connection
  /// events.
  final String eventId;
  final DateTime timestamp;
  const RealtimeEvent({required this.eventId, required this.timestamp});
}

/// Server emitted an event whose `type` we don't recognise. Carries the
/// raw JSON so callers can inspect or debug.
class UnknownRealtimeEvent extends RealtimeEvent {
  final String type;
  final Map<String, dynamic> raw;
  const UnknownRealtimeEvent({
    required super.eventId,
    required super.timestamp,
    required this.type,
    required this.raw,
  });
}

// ---------------------------------------------------------------------------
// Session events
// ---------------------------------------------------------------------------

abstract class SessionEvent extends RealtimeEvent {
  const SessionEvent({required super.eventId, required super.timestamp});
}

class SessionCreated extends SessionEvent {
  final String sessionId;
  final Map<String, dynamic> session;
  const SessionCreated({
    required super.eventId,
    required super.timestamp,
    required this.sessionId,
    required this.session,
  });
}

class SessionUpdated extends SessionEvent {
  final String sessionId;
  final Map<String, dynamic> session;
  const SessionUpdated({
    required super.eventId,
    required super.timestamp,
    required this.sessionId,
    required this.session,
  });
}

// ---------------------------------------------------------------------------
// Conversation events
// ---------------------------------------------------------------------------

abstract class ConversationEvent extends RealtimeEvent {
  const ConversationEvent({required super.eventId, required super.timestamp});
}

class ConversationCreated extends ConversationEvent {
  final String conversationId;
  const ConversationCreated({
    required super.eventId,
    required super.timestamp,
    required this.conversationId,
  });
}

class ConversationItemCreated extends ConversationEvent {
  final String? previousItemId;
  final ConversationItem item;
  const ConversationItemCreated({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    required this.item,
  });
}

class ConversationItemAdded extends ConversationEvent {
  final String? previousItemId;
  final ConversationItem item;
  const ConversationItemAdded({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    required this.item,
  });
}

class ConversationItemDone extends ConversationEvent {
  final ConversationItem item;
  const ConversationItemDone({
    required super.eventId,
    required super.timestamp,
    required this.item,
  });
}

class ConversationItemRetrieved extends ConversationEvent {
  final ConversationItem item;
  const ConversationItemRetrieved({
    required super.eventId,
    required super.timestamp,
    required this.item,
  });
}

class ConversationItemDeleted extends ConversationEvent {
  final String itemId;
  const ConversationItemDeleted({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
  });
}

class ConversationItemTruncated extends ConversationEvent {
  final String itemId;
  final int contentIndex;
  final int audioEndMs;
  const ConversationItemTruncated({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.audioEndMs,
  });
}

class InputAudioTranscriptionDelta extends ConversationEvent {
  final String itemId;
  final int contentIndex;
  final String delta;
  const InputAudioTranscriptionDelta({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

class InputAudioTranscriptionCompleted extends ConversationEvent {
  final String itemId;
  final int contentIndex;
  final String transcript;
  final Map<String, dynamic>? usage;
  const InputAudioTranscriptionCompleted({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.transcript,
    this.usage,
  });
}

class InputAudioTranscriptionFailed extends ConversationEvent {
  final String itemId;
  final int contentIndex;
  final Map<String, dynamic> error;
  const InputAudioTranscriptionFailed({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.error,
  });
}

// ---------------------------------------------------------------------------
// Response events
// ---------------------------------------------------------------------------

abstract class ResponseEvent extends RealtimeEvent {
  final String responseId;
  const ResponseEvent({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

class ResponseCreated extends ResponseEvent {
  final Map<String, dynamic> response;
  const ResponseCreated({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.response,
  });
}

/// The `usage` block of `response.done`, parsed into a typed shape.
class RealtimeUsage {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int cachedTokens;
  final int inputTextTokens;
  final int inputAudioTokens;
  final int outputTextTokens;
  final int outputAudioTokens;
  const RealtimeUsage({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedTokens,
    required this.inputTextTokens,
    required this.inputAudioTokens,
    required this.outputTextTokens,
    required this.outputAudioTokens,
  });
  factory RealtimeUsage.fromJson(Map<String, dynamic> json) {
    int n(Object? v) => v is num ? v.toInt() : 0;
    final input = json['input_token_details'] as Map<String, dynamic>?;
    final output = json['output_token_details'] as Map<String, dynamic>?;
    return RealtimeUsage(
      totalTokens: n(json['total_tokens']),
      inputTokens: n(json['input_tokens']),
      outputTokens: n(json['output_tokens']),
      cachedTokens: n(input?['cached_tokens']),
      inputTextTokens: n(input?['text_tokens']),
      inputAudioTokens: n(input?['audio_tokens']),
      outputTextTokens: n(output?['text_tokens']),
      outputAudioTokens: n(output?['audio_tokens']),
    );
  }
}

class ResponseDone extends ResponseEvent {
  final Map<String, dynamic> response;
  /// `null` until the response actually finishes (no usage on cancellation).
  final RealtimeUsage? usage;
  /// One of `completed`, `cancelled`, `failed`, `incomplete`.
  final String? status;
  const ResponseDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.response,
    this.usage,
    this.status,
  });
}

class ResponseOutputItemAdded extends ResponseEvent {
  final String itemId;
  final int outputIndex;
  final ConversationItem item;
  const ResponseOutputItemAdded({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.item,
  });
}

class ResponseOutputItemDone extends ResponseEvent {
  final String itemId;
  final int outputIndex;
  final ConversationItem item;
  const ResponseOutputItemDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.item,
  });
}

class ResponseContentPartAdded extends ResponseEvent {
  final String itemId;
  final int outputIndex;
  final int contentIndex;
  final ContentPart part;
  const ResponseContentPartAdded({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.part,
  });
}

class ResponseContentPartDone extends ResponseEvent {
  final String itemId;
  final int outputIndex;
  final int contentIndex;
  final ContentPart part;
  const ResponseContentPartDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.outputIndex,
    required this.contentIndex,
    required this.part,
  });
}

class ResponseTextDelta extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  final String delta;
  const ResponseTextDelta({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

class ResponseTextDone extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  final String text;
  const ResponseTextDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
    required this.text,
  });
}

class ResponseAudioTranscriptDelta extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  final String delta;
  const ResponseAudioTranscriptDelta({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

class ResponseAudioTranscriptDone extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  final String transcript;
  const ResponseAudioTranscriptDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
    required this.transcript,
  });
}

class ResponseAudioDelta extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  /// Base64-encoded PCM audio. Only fires on the WebSocket transport;
  /// WebRTC delivers audio over the [RTCPeerConnection] track instead.
  final String delta;
  const ResponseAudioDelta({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

class ResponseAudioDone extends ResponseEvent {
  final String itemId;
  final int contentIndex;
  const ResponseAudioDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
  });
}

class ResponseFunctionCallArgumentsDelta extends ResponseEvent {
  final String itemId;
  final String callId;
  final String delta;
  const ResponseFunctionCallArgumentsDelta({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.callId,
    required this.delta,
  });
}

class ResponseFunctionCallArgumentsDone extends ResponseEvent {
  final String itemId;
  final String callId;
  /// JSON-encoded arguments string. Decode with `jsonDecode(arguments)`.
  final String arguments;
  const ResponseFunctionCallArgumentsDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.callId,
    required this.arguments,
  });
}

// ---------------------------------------------------------------------------
// Audio buffer events
// ---------------------------------------------------------------------------

abstract class AudioEvent extends RealtimeEvent {
  const AudioEvent({required super.eventId, required super.timestamp});
}

/// Server VAD detected end-of-speech but the audio buffer has been silent
/// long enough that no speech-start ever fired. WebRTC only.
class InputAudioBufferTimeoutTriggered extends AudioEvent {
  final int audioStartMs;
  final int audioEndMs;
  final String itemId;
  const InputAudioBufferTimeoutTriggered({
    required super.eventId,
    required super.timestamp,
    required this.audioStartMs,
    required this.audioEndMs,
    required this.itemId,
  });
}

class InputAudioBufferSpeechStarted extends AudioEvent {
  final int? audioStartMs;
  final String? itemId;
  const InputAudioBufferSpeechStarted({
    required super.eventId,
    required super.timestamp,
    this.audioStartMs,
    this.itemId,
  });
}

class InputAudioBufferSpeechStopped extends AudioEvent {
  final int? audioEndMs;
  final String? itemId;
  const InputAudioBufferSpeechStopped({
    required super.eventId,
    required super.timestamp,
    this.audioEndMs,
    this.itemId,
  });
}

class InputAudioBufferCommitted extends AudioEvent {
  final String? previousItemId;
  final String? itemId;
  const InputAudioBufferCommitted({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    this.itemId,
  });
}

class InputAudioBufferCleared extends AudioEvent {
  const InputAudioBufferCleared({
    required super.eventId,
    required super.timestamp,
  });
}

/// WebRTC-only. Server has begun delivering output audio frames over the
/// audio track for [responseId].
class OutputAudioBufferStarted extends AudioEvent {
  final String responseId;
  const OutputAudioBufferStarted({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

class OutputAudioBufferStopped extends AudioEvent {
  final String responseId;
  const OutputAudioBufferStopped({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

class OutputAudioBufferCleared extends AudioEvent {
  final String responseId;
  const OutputAudioBufferCleared({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

// ---------------------------------------------------------------------------
// Rate limit events
// ---------------------------------------------------------------------------

class RateLimit {
  final String name; // 'requests' or 'tokens'
  final int limit;
  final int remaining;
  /// Seconds until reset, as reported on the wire.
  final double resetSeconds;
  const RateLimit({
    required this.name,
    required this.limit,
    required this.remaining,
    required this.resetSeconds,
  });
}

class RateLimitsUpdated extends RealtimeEvent {
  final List<RateLimit> rateLimits;
  const RateLimitsUpdated({
    required super.eventId,
    required super.timestamp,
    required this.rateLimits,
  });
}

// ---------------------------------------------------------------------------
// Error event
// ---------------------------------------------------------------------------

class ErrorEvent extends RealtimeEvent {
  final String? type;
  final String? code;
  final String message;
  final String? param;
  /// `event_id` of the client event that triggered this error, if any.
  final String? errorEventId;
  const ErrorEvent({
    required super.eventId,
    required super.timestamp,
    required this.type,
    required this.code,
    required this.message,
    this.param,
    this.errorEventId,
  });
}

// ---------------------------------------------------------------------------
// Connection events (locally synthesized — not from the server)
// ---------------------------------------------------------------------------

abstract class ConnectionEvent extends RealtimeEvent {
  const ConnectionEvent({required super.eventId, required super.timestamp});
}

class ConnectionConnected extends ConnectionEvent {
  const ConnectionConnected({
    required super.eventId,
    required super.timestamp,
  });
}

class ConnectionDisconnected extends ConnectionEvent {
  final String reason;
  const ConnectionDisconnected({
    required super.eventId,
    required super.timestamp,
    required this.reason,
  });
}

class ConnectionFailed extends ConnectionEvent {
  final String error;
  const ConnectionFailed({
    required super.eventId,
    required super.timestamp,
    required this.error,
  });
}
