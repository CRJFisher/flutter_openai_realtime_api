/// Flutter client for the OpenAI Realtime API (WebRTC + WebSocket).
///
/// Public entry point: [RealtimeClient].
library flutter_openai_realtime_api;

export 'src/auth/ephemeral_token.dart'
    show
        EphemeralToken,
        EphemeralTokenProvider,
        CachingEphemeralTokenProvider,
        OpenAIClientSecretMinter,
        EphemeralTokenException;
export 'src/client/realtime_client.dart' show RealtimeClient;
export 'src/connection/realtime_transport.dart' show ConnectionState;
export 'src/internal/logger.dart' show RealtimeLogging;
export 'src/internal/protocol.dart' show RealtimeModel;
export 'src/models/config.dart' show RealtimeConfig;
export 'src/models/conversation_item.dart'
    show
        ConversationItem,
        ConversationItemType,
        ConversationItemStatus,
        ConversationRole,
        ContentPart,
        ContentType;
export 'src/models/enums.dart' show Voice, Modality, AudioFormat;
export 'src/models/events.dart';
export 'src/models/mute_strategy.dart' show MuteStrategy;
export 'src/models/tool.dart' show Tool, ToolChoice;
export 'src/models/transcription.dart'
    show TranscriptionConfig, TranscriptionModel;
export 'src/models/turn_detection.dart'
    show TurnDetection, ServerVad, SemanticVad, VadEagerness;
