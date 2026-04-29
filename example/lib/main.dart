// Example app for flutter_openai_realtime_api.
//
// LOCAL DEVELOPMENT ONLY. This example mints ephemeral tokens directly
// from the device using the long-lived OpenAI key in `.env`. Do not ship
// an app that does this — anyone who unpacks the binary will get the key.
// See the package README §Backend Setup for the production pattern.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_openai_realtime_api/flutter_openai_realtime_api.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  RealtimeLogging.enableConsoleOutput();
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();
  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  RealtimeClient? _client;
  StreamSubscription<RealtimeEvent>? _sub;
  final _transcript = <String>[];
  String? _activeAssistantTurn;
  String _status = 'idle';

  @override
  void dispose() {
    _sub?.cancel();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      _setStatus('microphone permission denied');
      return;
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _setStatus('OPENAI_API_KEY missing from .env');
      return;
    }

    // Local-dev token minter: calls the OpenAI client_secrets endpoint
    // directly. In production, replace with a provider that calls your
    // backend (see README §Backend Setup).
    final minter = OpenAIClientSecretMinter(apiKey: apiKey);
    final tokenProvider = CachingEphemeralTokenProvider(
      fetcher: () => minter.mint(
        sessionConfig: {
          'type': 'realtime',
          'model': RealtimeModel.gptRealtime.id
        },
        expiresInSeconds: 120,
      ),
    );

    final client = RealtimeClient.webRtc(RealtimeConfig(
      tokenProvider: tokenProvider,
      voice: Voice.alloy,
      instructions: 'You are a helpful, concise assistant. '
          'Keep replies to one or two sentences.',
      turnDetection: const ServerVad.quick(),
      muteStrategy: MuteStrategy.auto,
      inputAudioTranscription: const TranscriptionConfig(
        model: TranscriptionModel.whisper1,
        language: 'en',
      ),
    ));

    _sub = client.events.listen(_onEvent);
    setState(() => _client = client);

    _setStatus('connecting…');
    try {
      await client.connect();
      _setStatus('connected');
    } catch (e) {
      _setStatus('connect failed: $e');
    }
  }

  Future<void> _stop() async {
    final client = _client;
    setState(() => _client = null);
    await _sub?.cancel();
    _sub = null;
    await client?.dispose();
    _setStatus('disconnected');
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _status = s);
  }

  void _onEvent(RealtimeEvent event) {
    if (event is InputAudioTranscriptionCompleted) {
      setState(() => _transcript.add('You: ${event.transcript.trim()}'));
    } else if (event is ResponseAudioTranscriptDelta) {
      _activeAssistantTurn = (_activeAssistantTurn ?? '') + event.delta;
      setState(() {});
    } else if (event is ResponseAudioTranscriptDone) {
      final turn = (_activeAssistantTurn ?? event.transcript).trim();
      setState(() {
        _transcript.add('AI: $turn');
        _activeAssistantTurn = null;
      });
    } else if (event is ResponseTextDelta) {
      _activeAssistantTurn = (_activeAssistantTurn ?? '') + event.delta;
      setState(() {});
    } else if (event is ErrorEvent) {
      _setStatus('error: ${event.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _client != null;
    return Scaffold(
      appBar: AppBar(title: Text('Realtime Demo · $_status')),
      body: Column(
        children: [
          if (connected) _MuteToggle(client: _client!),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final line in _transcript)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line),
                  ),
                if (_activeAssistantTurn != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'AI: $_activeAssistantTurn…',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: connected ? _stop : _start,
              icon: Icon(connected ? Icons.stop : Icons.mic),
              label: Text(connected ? 'Stop' : 'Start conversation'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuteToggle extends StatelessWidget {
  const _MuteToggle({required this.client});
  final RealtimeClient client;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: client.isMuted,
      builder: (context, muted, _) {
        return SwitchListTile(
          title: Text(muted ? 'Mic muted' : 'Mic open'),
          value: muted,
          onChanged: (v) => client.setMuted(v),
          secondary: Icon(muted ? Icons.mic_off : Icons.mic),
        );
      },
    );
  }
}
