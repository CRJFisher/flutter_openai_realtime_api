/// Server-side voice activity detection configuration.
///
/// Set `RealtimeConfig.turnDetection` to `null` for manual / push-to-talk
/// mode (the client commits the input audio buffer and creates responses
/// explicitly).
sealed class TurnDetection {
  const TurnDetection();
  Map<String, dynamic> toJson();
}

/// Audio-level VAD. Fast, simple, no transcription cost.
final class ServerVad extends TurnDetection {
  /// Activation threshold, 0.0–1.0. Higher = less sensitive. Default 0.5.
  final double? threshold;

  /// Audio (ms) included before detected speech. Default 300.
  final int? prefixPaddingMs;

  /// Silence (ms) before end-of-speech is declared. Default 500.
  final int? silenceDurationMs;

  /// If non-null, end-of-speech is auto-declared after this much idle
  /// audio even if speech never started. Server emits
  /// `input_audio_buffer.timeout_triggered`. WebSocket transport does
  /// not currently fire this event — WebRTC does.
  final int? idleTimeoutMs;

  /// Auto-call `response.create` after end-of-speech. Default `true`.
  final bool? createResponse;

  /// Auto-cancel the active response when the user starts speaking.
  /// Default `true`.
  final bool? interruptResponse;

  const ServerVad({
    this.threshold,
    this.prefixPaddingMs,
    this.silenceDurationMs,
    this.idleTimeoutMs,
    this.createResponse,
    this.interruptResponse,
  });

  /// Sensitive: fast turn-taking, suitable for snappy chat.
  const ServerVad.quick()
    : this(threshold: 0.5, prefixPaddingMs: 300, silenceDurationMs: 500);

  /// Patient: longer pauses tolerated. Suitable for thoughtful conversation.
  const ServerVad.patient()
    : this(threshold: 0.8, prefixPaddingMs: 800, silenceDurationMs: 2500);

  /// Aggressive thresholds tuned to suppress feedback on devices with
  /// poor hardware echo cancellation (e.g. Android without headphones).
  /// Use together with `MuteStrategy.aggressive`.
  const ServerVad.preventFeedback()
    : this(threshold: 0.9, prefixPaddingMs: 1000, silenceDurationMs: 3500);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'server_vad',
    if (threshold != null) 'threshold': threshold,
    if (prefixPaddingMs != null) 'prefix_padding_ms': prefixPaddingMs,
    if (silenceDurationMs != null) 'silence_duration_ms': silenceDurationMs,
    if (idleTimeoutMs != null) 'idle_timeout_ms': idleTimeoutMs,
    if (createResponse != null) 'create_response': createResponse,
    if (interruptResponse != null) 'interrupt_response': interruptResponse,
  };
}

/// Eagerness of semantic VAD.
enum VadEagerness {
  low('low'),
  medium('medium'),
  high('high'),
  auto('auto');

  const VadEagerness(this.id);
  final String id;
}

/// Semantic VAD. Uses a model to detect end-of-turn from conversation
/// context. More accurate than `ServerVad` for conversational speech but
/// adds inference cost.
final class SemanticVad extends TurnDetection {
  final VadEagerness? eagerness;
  final bool? createResponse;
  final bool? interruptResponse;

  const SemanticVad({
    this.eagerness,
    this.createResponse,
    this.interruptResponse,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'semantic_vad',
    if (eagerness != null) 'eagerness': eagerness!.id,
    if (createResponse != null) 'create_response': createResponse,
    if (interruptResponse != null) 'interrupt_response': interruptResponse,
  };
}
