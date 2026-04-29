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

  /// Wall-clock time at which the event was received by the client.
  final DateTime timestamp;
  const RealtimeEvent({required this.eventId, required this.timestamp});
}

/// Server emitted an event whose `type` we don't recognise. Carries the
/// raw JSON so callers can inspect or debug.
class UnknownRealtimeEvent extends RealtimeEvent {
  /// The unrecognised `type` string from the server payload.
  final String type;

  /// The full server payload as a JSON-decoded map.
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

/// Base class for session lifecycle events ([SessionCreated], [SessionUpdated]).
abstract class SessionEvent extends RealtimeEvent {
  const SessionEvent({required super.eventId, required super.timestamp});
}

/// Emitted once per connection when the server has accepted the session.
class SessionCreated extends SessionEvent {
  /// Server-assigned id for this session.
  final String sessionId;

  /// Full `session` object from the server (raw JSON).
  final Map<String, dynamic> session;
  const SessionCreated({
    required super.eventId,
    required super.timestamp,
    required this.sessionId,
    required this.session,
  });
}

/// Emitted in response to a `session.update` request, reflecting the new
/// effective session configuration.
class SessionUpdated extends SessionEvent {
  /// Server-assigned id for this session.
  final String sessionId;

  /// Full `session` object after the update (raw JSON).
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

/// Base class for events about the conversation log: items being added,
/// removed, transcribed, etc.
abstract class ConversationEvent extends RealtimeEvent {
  const ConversationEvent({required super.eventId, required super.timestamp});
}

/// A new conversation has been created on the server.
class ConversationCreated extends ConversationEvent {
  /// Server-assigned id for the conversation.
  final String conversationId;
  const ConversationCreated({
    required super.eventId,
    required super.timestamp,
    required this.conversationId,
  });
}

/// Server acknowledged a `conversation.item.create` and added the item
/// to the conversation log.
class ConversationItemCreated extends ConversationEvent {
  /// Item that this one was inserted after, if any.
  final String? previousItemId;

  /// The newly-created conversation item.
  final ConversationItem item;
  const ConversationItemCreated({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    required this.item,
  });
}

/// A conversation item has begun streaming in (e.g. an assistant message
/// whose content parts will arrive over subsequent events).
class ConversationItemAdded extends ConversationEvent {
  /// Item that this one was inserted after, if any.
  final String? previousItemId;

  /// The newly-added conversation item.
  final ConversationItem item;
  const ConversationItemAdded({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    required this.item,
  });
}

/// A conversation item has finished streaming and is now in its final form.
class ConversationItemDone extends ConversationEvent {
  /// The finalised conversation item.
  final ConversationItem item;
  const ConversationItemDone({
    required super.eventId,
    required super.timestamp,
    required this.item,
  });
}

/// Response to a `conversation.item.retrieve` request.
class ConversationItemRetrieved extends ConversationEvent {
  /// The retrieved conversation item.
  final ConversationItem item;
  const ConversationItemRetrieved({
    required super.eventId,
    required super.timestamp,
    required this.item,
  });
}

/// A conversation item has been deleted from the log.
class ConversationItemDeleted extends ConversationEvent {
  /// Id of the item that was deleted.
  final String itemId;
  const ConversationItemDeleted({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
  });
}

/// A conversation item's audio has been truncated to a specific cutoff —
/// typically because the user interrupted the assistant.
class ConversationItemTruncated extends ConversationEvent {
  /// Id of the item that was truncated.
  final String itemId;

  /// Index of the content part within the item.
  final int contentIndex;

  /// New length of the audio content in milliseconds.
  final int audioEndMs;
  const ConversationItemTruncated({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.audioEndMs,
  });
}

/// Streaming partial transcription of user input audio.
class InputAudioTranscriptionDelta extends ConversationEvent {
  /// Id of the conversation item being transcribed.
  final String itemId;

  /// Index of the content part within the item.
  final int contentIndex;

  /// New text appended to the running transcript.
  final String delta;
  const InputAudioTranscriptionDelta({
    required super.eventId,
    required super.timestamp,
    required this.itemId,
    required this.contentIndex,
    required this.delta,
  });
}

/// Final transcript for a user audio item.
class InputAudioTranscriptionCompleted extends ConversationEvent {
  /// Id of the conversation item that was transcribed.
  final String itemId;

  /// Index of the content part within the item.
  final int contentIndex;

  /// The full final transcript.
  final String transcript;

  /// Optional transcription usage block (raw JSON), if reported.
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

/// Transcription of a user audio item failed.
class InputAudioTranscriptionFailed extends ConversationEvent {
  /// Id of the conversation item whose transcription failed.
  final String itemId;

  /// Index of the content part within the item.
  final int contentIndex;

  /// Server-provided error payload (raw JSON).
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

/// Base class for all events scoped to a single model response in flight.
abstract class ResponseEvent extends RealtimeEvent {
  /// Server-assigned id of the response this event belongs to.
  final String responseId;
  const ResponseEvent({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

/// A new model response has been created and will begin streaming.
class ResponseCreated extends ResponseEvent {
  /// Full `response` object from the server (raw JSON).
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
  /// Total tokens consumed (input + output).
  final int totalTokens;

  /// Total input tokens.
  final int inputTokens;

  /// Total output tokens.
  final int outputTokens;

  /// Input tokens served from the prompt cache.
  final int cachedTokens;

  /// Input text tokens.
  final int inputTextTokens;

  /// Input audio tokens.
  final int inputAudioTokens;

  /// Output text tokens.
  final int outputTextTokens;

  /// Output audio tokens.
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

/// The model response has finished streaming. Final usage and status are
/// reported here.
class ResponseDone extends ResponseEvent {
  /// Full final `response` object from the server (raw JSON).
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

/// A new output item (e.g. an assistant message) has begun in the response.
class ResponseOutputItemAdded extends ResponseEvent {
  /// Id of the new output item.
  final String itemId;

  /// Position of this item in the response output array.
  final int outputIndex;

  /// The output item itself.
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

/// An output item in the response has finished streaming.
class ResponseOutputItemDone extends ResponseEvent {
  /// Id of the finished output item.
  final String itemId;

  /// Position of this item in the response output array.
  final int outputIndex;

  /// The finalised output item.
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

/// A new content part (text, audio, …) has been added to an output item.
class ResponseContentPartAdded extends ResponseEvent {
  /// Id of the output item this content part belongs to.
  final String itemId;

  /// Position of the parent item in the response output array.
  final int outputIndex;

  /// Position of this content part within the item.
  final int contentIndex;

  /// The new content part.
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

/// A content part has finished streaming.
class ResponseContentPartDone extends ResponseEvent {
  /// Id of the output item this content part belongs to.
  final String itemId;

  /// Position of the parent item in the response output array.
  final int outputIndex;

  /// Position of this content part within the item.
  final int contentIndex;

  /// The finalised content part.
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

/// Streaming partial text from the assistant.
class ResponseTextDelta extends ResponseEvent {
  /// Id of the output item being extended.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;

  /// New text appended to the running content.
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

/// Final text content for an assistant output item.
class ResponseTextDone extends ResponseEvent {
  /// Id of the finished output item.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;

  /// The complete text.
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

/// Streaming partial transcript of the assistant's spoken audio.
class ResponseAudioTranscriptDelta extends ResponseEvent {
  /// Id of the output item being extended.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;

  /// New text appended to the running transcript.
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

/// Final transcript of the assistant's spoken audio for an output item.
class ResponseAudioTranscriptDone extends ResponseEvent {
  /// Id of the finished output item.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;

  /// The complete transcript.
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

/// Streaming PCM audio chunk from the assistant. WebSocket transport only.
class ResponseAudioDelta extends ResponseEvent {
  /// Id of the output item being extended.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;

  /// Base64-encoded PCM audio. Only fires on the WebSocket transport;
  /// WebRTC delivers audio over the `RTCPeerConnection` track instead.
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

/// Final marker for assistant audio on an output item. WebSocket transport
/// only.
class ResponseAudioDone extends ResponseEvent {
  /// Id of the finished output item.
  final String itemId;

  /// Position of the content part within the item.
  final int contentIndex;
  const ResponseAudioDone({
    required super.eventId,
    required super.timestamp,
    required super.responseId,
    required this.itemId,
    required this.contentIndex,
  });
}

/// Streaming partial JSON arguments for a function/tool call.
class ResponseFunctionCallArgumentsDelta extends ResponseEvent {
  /// Id of the output item carrying the call.
  final String itemId;

  /// Server-assigned id for the call. Use this to correlate with the
  /// `function_call_output` you submit back.
  final String callId;

  /// New text appended to the running arguments JSON string.
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

/// Final JSON arguments for a function/tool call.
class ResponseFunctionCallArgumentsDone extends ResponseEvent {
  /// Id of the output item carrying the call.
  final String itemId;

  /// Server-assigned id for the call.
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

/// Base class for input/output audio buffer lifecycle events.
abstract class AudioEvent extends RealtimeEvent {
  const AudioEvent({required super.eventId, required super.timestamp});
}

/// Server VAD detected end-of-speech but the audio buffer has been silent
/// long enough that no speech-start ever fired. WebRTC only.
class InputAudioBufferTimeoutTriggered extends AudioEvent {
  /// Offset in ms within the audio buffer where speech was expected to start.
  final int audioStartMs;

  /// Offset in ms within the audio buffer where the timeout fired.
  final int audioEndMs;

  /// Id of the conversation item that would have been created.
  final String itemId;
  const InputAudioBufferTimeoutTriggered({
    required super.eventId,
    required super.timestamp,
    required this.audioStartMs,
    required this.audioEndMs,
    required this.itemId,
  });
}

/// Server VAD detected the start of user speech.
class InputAudioBufferSpeechStarted extends AudioEvent {
  /// Offset in ms within the audio buffer where speech began, if reported.
  final int? audioStartMs;

  /// Id the server will use for the resulting input item, if reported.
  final String? itemId;
  const InputAudioBufferSpeechStarted({
    required super.eventId,
    required super.timestamp,
    this.audioStartMs,
    this.itemId,
  });
}

/// Server VAD detected the end of user speech.
class InputAudioBufferSpeechStopped extends AudioEvent {
  /// Offset in ms within the audio buffer where speech ended, if reported.
  final int? audioEndMs;

  /// Id the server will use for the resulting input item, if reported.
  final String? itemId;
  const InputAudioBufferSpeechStopped({
    required super.eventId,
    required super.timestamp,
    this.audioEndMs,
    this.itemId,
  });
}

/// The pending input audio buffer has been committed as a conversation item.
class InputAudioBufferCommitted extends AudioEvent {
  /// Item that this one was inserted after, if any.
  final String? previousItemId;

  /// Id of the conversation item produced from the committed buffer.
  final String? itemId;
  const InputAudioBufferCommitted({
    required super.eventId,
    required super.timestamp,
    this.previousItemId,
    this.itemId,
  });
}

/// The pending input audio buffer has been cleared without being committed.
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

/// WebRTC-only. Server has finished delivering output audio frames for
/// [responseId].
class OutputAudioBufferStopped extends AudioEvent {
  /// Id of the response whose audio output has finished.
  final String responseId;
  const OutputAudioBufferStopped({
    required super.eventId,
    required super.timestamp,
    required this.responseId,
  });
}

/// WebRTC-only. The output audio buffer was cleared mid-response, typically
/// as a result of the user interrupting.
class OutputAudioBufferCleared extends AudioEvent {
  /// Id of the response whose audio output was cleared.
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

/// A single rate-limit bucket reported by the server (e.g. "requests" or
/// "tokens").
class RateLimit {
  /// Bucket name — typically `'requests'` or `'tokens'`.
  final String name;

  /// Maximum number of units permitted in the current window.
  final int limit;

  /// Units remaining before the bucket is exhausted.
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

/// Periodic snapshot of the server's rate-limit state.
class RateLimitsUpdated extends RealtimeEvent {
  /// One entry per bucket reported by the server.
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

/// Server-reported error. May be fatal (connection-terminating) or scoped
/// to a single client event.
class ErrorEvent extends RealtimeEvent {
  /// Server-provided error type, if any.
  final String? type;

  /// Server-provided error code, if any.
  final String? code;

  /// Human-readable error message.
  final String message;

  /// Server-provided parameter name that caused the error, if any.
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

/// Base class for client-side connection lifecycle events. These are
/// synthesised locally — they are not received from the server.
abstract class ConnectionEvent extends RealtimeEvent {
  const ConnectionEvent({required super.eventId, required super.timestamp});
}

/// The transport has connected and the session is ready to use.
class ConnectionConnected extends ConnectionEvent {
  const ConnectionConnected({
    required super.eventId,
    required super.timestamp,
  });
}

/// The transport disconnected cleanly (e.g. via `RealtimeClient.dispose()`).
class ConnectionDisconnected extends ConnectionEvent {
  /// Reason the transport disconnected.
  final String reason;
  const ConnectionDisconnected({
    required super.eventId,
    required super.timestamp,
    required this.reason,
  });
}

/// The transport failed unexpectedly (e.g. ICE failure, socket error).
class ConnectionFailed extends ConnectionEvent {
  /// Description of the failure.
  final String error;
  const ConnectionFailed({
    required super.eventId,
    required super.timestamp,
    required this.error,
  });
}
