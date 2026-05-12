import '../auth/ephemeral_token.dart';
import '../internal/protocol.dart';
import 'enums.dart';
import 'mute_strategy.dart';
import 'tool.dart';
import 'transcription.dart';
import 'turn_detection.dart';

/// Configuration for a Realtime session.
///
/// One of [apiKey] or [tokenProvider] must be provided. Use [tokenProvider]
/// (an ephemeral key minted by your backend) for any client-side build.
/// Direct [apiKey] use is for server-side or local development only.
class RealtimeConfig {
  /// Long-lived OpenAI API key (`sk-...`). **Never embed this in a Flutter
  /// app shipped to users.** Use [tokenProvider] instead.
  final String? apiKey;

  /// Provides ephemeral client secrets minted by your backend.
  final EphemeralTokenProvider? tokenProvider;

  /// Override base URL. Defaults to `https://api.openai.com`.
  final String? baseUrl;

  /// ICE servers for the WebRTC peer connection. Defaults to a single
  /// public Google STUN server. Provide TURN credentials here if your
  /// users are behind symmetric NAT.
  final List<Map<String, dynamic>>? iceServers;

  final RealtimeModel model;
  final List<Modality> outputModalities;
  final Voice? voice;
  final String? instructions;

  /// PCM/G.711 format for the WebSocket transport's input audio. Has no
  /// effect on WebRTC (Opus 48 kHz on the audio track).
  final AudioFormat inputAudioFormat;

  /// PCM/G.711 format for the WebSocket transport's output audio.
  final AudioFormat outputAudioFormat;

  final TranscriptionConfig? inputAudioTranscription;

  /// `null` disables server VAD (manual / push-to-talk mode).
  final TurnDetection? turnDetection;

  final List<Tool> tools;
  final ToolChoice toolChoice;
  final double temperature;

  /// `null` lets the server decide. Set this to cap costs per response.
  final int? maxOutputTokens;

  // -- Transport-side options --

  final MuteStrategy muteStrategy;
  final bool enableEchoCancellation;
  final bool enableNoiseSuppression;
  final bool enableAutoGainControl;

  const RealtimeConfig({
    this.apiKey,
    this.tokenProvider,
    this.baseUrl,
    this.iceServers,
    this.model = RealtimeModel.gptRealtime2,
    this.outputModalities = const [Modality.text, Modality.audio],
    this.voice,
    this.instructions,
    this.inputAudioFormat = AudioFormat.pcm16,
    this.outputAudioFormat = AudioFormat.pcm16,
    this.inputAudioTranscription,
    this.turnDetection = const ServerVad.quick(),
    this.tools = const [],
    this.toolChoice = const ToolChoice.auto(),
    this.temperature = 0.8,
    this.maxOutputTokens,
    this.muteStrategy = MuteStrategy.auto,
    this.enableEchoCancellation = true,
    this.enableNoiseSuppression = true,
    this.enableAutoGainControl = true,
  }) : assert(
         apiKey != null || tokenProvider != null,
         'RealtimeConfig requires either apiKey or tokenProvider.',
       ),
       assert(
         apiKey == null || tokenProvider == null,
         'RealtimeConfig: pass apiKey OR tokenProvider, not both.',
       );

  /// Body for `session.update` and the `session` field in
  /// `client_secrets` requests. Uses the GA discriminated `audio.{input,
  /// output}` schema rather than the pre-GA flat shape.
  Map<String, dynamic> toSessionJson() {
    final audio = <String, dynamic>{
      'input': {
        'format': _audioFormatJson(inputAudioFormat),
        if (inputAudioTranscription != null)
          'transcription': inputAudioTranscription!.toJson(),
        if (turnDetection != null) 'turn_detection': turnDetection!.toJson(),
      },
      'output': {
        'format': _audioFormatJson(outputAudioFormat),
        if (voice != null) 'voice': voice!.id,
      },
    };

    return {
      'type': 'realtime',
      'model': model.id,
      'output_modalities': outputModalities.map((m) => m.id).toList(),
      if (instructions != null) 'instructions': instructions,
      'audio': audio,
      'tools': tools.map((t) => t.toJson()).toList(),
      'tool_choice': toolChoice.toJson(),
      'temperature': temperature,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    };
  }

  static Map<String, dynamic> _audioFormatJson(AudioFormat f) {
    switch (f) {
      case AudioFormat.pcm16:
        return {'type': 'audio/pcm', 'rate': 24000};
      case AudioFormat.g711Ulaw:
        return {'type': 'audio/pcmu'};
      case AudioFormat.g711Alaw:
        return {'type': 'audio/pcma'};
    }
  }

  /// Resolves to an `Authorization` Bearer string. Calls [tokenProvider]
  /// if one is configured.
  Future<String> resolveBearerToken() async {
    if (apiKey != null) return apiKey!;
    final token = await tokenProvider!.getToken();
    return token.value;
  }

  /// Resolved base URL with no trailing slash.
  String get effectiveBaseUrl {
    final base = baseUrl ?? Protocol.apiBaseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}
