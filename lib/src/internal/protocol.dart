/// Internal protocol constants for the OpenAI Realtime GA API.
///
/// Not exported from the public barrel.
class Protocol {
  static const apiBaseUrl = 'https://api.openai.com';

  /// Mints an ephemeral client secret (`ek_...`).
  static const clientSecretsPath = '/v1/realtime/client_secrets';

  /// SDP exchange for WebRTC. Bearer must be an ephemeral key.
  static const callsPath = '/v1/realtime/calls';

  /// WebSocket path. Model is selected via the `?model=` query parameter.
  static const webSocketPath = '/v1/realtime';

  /// DataChannel label OpenAI's WebRTC samples use.
  static const dataChannelLabel = 'oai-events';

  /// Hard server-side cap on session length. Mint a fresh ephemeral
  /// to reconnect when the cap is reached.
  static const sessionDurationCap = Duration(minutes: 30);

  // -- Client → server event types --
  static const sessionUpdate = 'session.update';
  static const inputAudioBufferAppend = 'input_audio_buffer.append';
  static const inputAudioBufferCommit = 'input_audio_buffer.commit';
  static const inputAudioBufferClear = 'input_audio_buffer.clear';
  static const outputAudioBufferClear = 'output_audio_buffer.clear';
  static const conversationItemCreate = 'conversation.item.create';
  static const conversationItemTruncate = 'conversation.item.truncate';
  static const conversationItemDelete = 'conversation.item.delete';
  static const responseCreate = 'response.create';
  static const responseCancel = 'response.cancel';

  // -- Server → client event types --
  // Session
  static const sessionCreated = 'session.created';
  static const sessionUpdated = 'session.updated';

  // Conversation
  static const conversationCreated = 'conversation.created';
  static const conversationItemCreated = 'conversation.item.created';
  static const conversationItemAdded = 'conversation.item.added';
  static const conversationItemDone = 'conversation.item.done';
  static const conversationItemRetrieved = 'conversation.item.retrieved';
  static const conversationItemDeleted = 'conversation.item.deleted';
  static const conversationItemTruncated = 'conversation.item.truncated';

  // Input audio transcription
  static const inputAudioTranscriptionDelta =
      'conversation.item.input_audio_transcription.delta';
  static const inputAudioTranscriptionCompleted =
      'conversation.item.input_audio_transcription.completed';
  static const inputAudioTranscriptionFailed =
      'conversation.item.input_audio_transcription.failed';

  // Input audio buffer
  static const inputAudioBufferCommitted = 'input_audio_buffer.committed';
  static const inputAudioBufferCleared = 'input_audio_buffer.cleared';
  static const inputAudioBufferSpeechStarted =
      'input_audio_buffer.speech_started';
  static const inputAudioBufferSpeechStopped =
      'input_audio_buffer.speech_stopped';
  static const inputAudioBufferTimeoutTriggered =
      'input_audio_buffer.timeout_triggered';

  // Output audio buffer (WebRTC only)
  static const outputAudioBufferStarted = 'output_audio_buffer.started';
  static const outputAudioBufferStopped = 'output_audio_buffer.stopped';
  static const outputAudioBufferCleared = 'output_audio_buffer.cleared';

  // Response lifecycle
  static const responseCreated = 'response.created';
  static const responseDone = 'response.done';
  static const responseOutputItemAdded = 'response.output_item.added';
  static const responseOutputItemDone = 'response.output_item.done';
  static const responseContentPartAdded = 'response.content_part.added';
  static const responseContentPartDone = 'response.content_part.done';

  // Response text — GA names plus pre-GA aliases
  static const responseOutputTextDelta = 'response.output_text.delta';
  static const responseOutputTextDone = 'response.output_text.done';
  static const responseTextDeltaPreGA = 'response.text.delta';
  static const responseTextDonePreGA = 'response.text.done';

  // Response audio — GA names plus pre-GA aliases
  static const responseOutputAudioDelta = 'response.output_audio.delta';
  static const responseOutputAudioDone = 'response.output_audio.done';
  static const responseAudioDeltaPreGA = 'response.audio.delta';
  static const responseAudioDonePreGA = 'response.audio.done';

  // Response audio transcript — GA names plus pre-GA aliases
  static const responseOutputAudioTranscriptDelta =
      'response.output_audio_transcript.delta';
  static const responseOutputAudioTranscriptDone =
      'response.output_audio_transcript.done';
  static const responseAudioTranscriptDeltaPreGA =
      'response.audio_transcript.delta';
  static const responseAudioTranscriptDonePreGA =
      'response.audio_transcript.done';

  // Function calls
  static const responseFunctionCallArgumentsDelta =
      'response.function_call_arguments.delta';
  static const responseFunctionCallArgumentsDone =
      'response.function_call_arguments.done';

  // Other
  static const rateLimitsUpdated = 'rate_limits.updated';
  static const error = 'error';
}

/// Models supported by the Realtime API.
///
/// Listed values are valid as of late 2025. The constants `gpt-4o-realtime-*`
/// shut down 2026-05-07; do not use them for new sessions.
enum RealtimeModel {
  /// Latest production model. Use this unless you have a reason not to.
  gptRealtime('gpt-realtime'),

  /// Smaller/cheaper variant of `gpt-realtime`.
  gptRealtimeMini('gpt-realtime-mini'),

  /// Dated snapshot of `gpt-realtime` (2025-08-28).
  gptRealtime20250828('gpt-realtime-2025-08-28');

  const RealtimeModel(this.id);
  final String id;
}
