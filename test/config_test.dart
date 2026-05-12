import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_openai_realtime_api/flutter_openai_realtime_api.dart';

class _StubProvider implements EphemeralTokenProvider {
  @override
  Future<EphemeralToken> getToken() async => EphemeralToken(
    value: 'ek_test',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  );
}

void main() {
  group('RealtimeConfig.toSessionJson', () {
    test('emits the GA discriminated audio.input/output schema', () {
      // Reviewer 5 caught: previous serializer emitted the pre-GA flat
      // schema (`modalities`, `voice` at root, string `input_audio_format`)
      // which `gpt-realtime*` rejects.
      const config = RealtimeConfig(
        apiKey: 'sk-test',
        voice: Voice.alloy,
        instructions: 'be helpful',
        outputModalities: [Modality.text, Modality.audio],
      );
      final json = config.toSessionJson();
      expect(json['type'], 'realtime');
      expect(json['model'], 'gpt-realtime');
      expect(json['output_modalities'], ['text', 'audio']);
      expect(json['instructions'], 'be helpful');

      final audio = json['audio'] as Map<String, dynamic>;
      expect(audio['input']['format'], {'type': 'audio/pcm', 'rate': 24000});
      expect(audio['output']['format'], {'type': 'audio/pcm', 'rate': 24000});
      expect(audio['output']['voice'], 'alloy');
    });

    test('serializes ServerVad turn_detection under audio.input', () {
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        turnDetection: ServerVad.patient(),
      ).toSessionJson();
      final input = (json['audio'] as Map)['input'] as Map<String, dynamic>;
      final td = input['turn_detection'] as Map<String, dynamic>;
      expect(td['type'], 'server_vad');
      expect(td['threshold'], 0.8);
      expect(td['silence_duration_ms'], 2500);
    });

    test('serializes SemanticVad with eagerness', () {
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        turnDetection: SemanticVad(eagerness: VadEagerness.high),
      ).toSessionJson();
      final td =
          ((json['audio'] as Map)['input'] as Map)['turn_detection']
              as Map<String, dynamic>;
      expect(td['type'], 'semantic_vad');
      expect(td['eagerness'], 'high');
    });

    test('omits turn_detection when null (manual mode)', () {
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        turnDetection: null,
      ).toSessionJson();
      final input = (json['audio'] as Map)['input'] as Map<String, dynamic>;
      expect(input.containsKey('turn_detection'), false);
    });

    test('Tool serializes with type:function', () {
      // Reviewer 6 caught: previous Tool.toJson omitted the discriminator,
      // so every tool the library shipped was malformed.
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        tools: [
          Tool(
            name: 'get_weather',
            description: 'Get current weather',
            parameters: {
              'type': 'object',
              'properties': {
                'location': {'type': 'string'},
              },
              'required': ['location'],
            },
          ),
        ],
      ).toSessionJson();

      final tools = json['tools'] as List;
      expect(tools.first['type'], 'function');
      expect(tools.first['name'], 'get_weather');
      expect(tools.first['parameters']['type'], 'object');
    });

    test('ToolChoice.function names a specific function', () {
      // Reviewer 6 caught: prior ToolChoice was an enum and could not
      // express specific-function selection.
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        toolChoice: ToolChoice.function('get_weather'),
      ).toSessionJson();
      final tc = json['tool_choice'] as Map<String, dynamic>;
      expect(tc['type'], 'function');
      expect(tc['function']['name'], 'get_weather');
    });

    test('uses g711 mime types for non-PCM formats', () {
      final json = const RealtimeConfig(
        apiKey: 'sk-test',
        inputAudioFormat: AudioFormat.g711Ulaw,
        outputAudioFormat: AudioFormat.g711Alaw,
      ).toSessionJson();
      final audio = json['audio'] as Map<String, dynamic>;
      expect(audio['input']['format'], {'type': 'audio/pcmu'});
      expect(audio['output']['format'], {'type': 'audio/pcma'});
    });

    test('asserts apiKey XOR tokenProvider', () {
      // Both null
      expect(() => RealtimeConfig(), throwsA(isA<AssertionError>()));
      // Both set
      expect(
        () => RealtimeConfig(apiKey: 'sk-test', tokenProvider: _StubProvider()),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Voice enum', () {
    test('contains all 10 Realtime voices', () {
      // Reviewer 5 caught: prior enum had `fable`, `nova`, `onyx` (TTS-
      // only voices the Realtime server rejects) and was missing `sage`,
      // `marin`, `cedar`.
      expect(Voice.values.map((v) => v.id).toSet(), {
        'alloy',
        'ash',
        'ballad',
        'coral',
        'echo',
        'sage',
        'shimmer',
        'verse',
        'marin',
        'cedar',
      });
    });
  });

  group('RealtimeModel enum', () {
    test('contains only current GA models', () {
      expect(RealtimeModel.values.map((m) => m.id).toSet(), {
        'gpt-realtime',
        'gpt-realtime-2',
        'gpt-realtime-1.5',
        'gpt-realtime-mini',
        'gpt-realtime-mini-2025-12-15',
        'gpt-realtime-mini-2025-10-06',
        'gpt-realtime-2025-08-28',
        'gpt-realtime-translate',
        'gpt-realtime-whisper',
      });
    });
  });
}
