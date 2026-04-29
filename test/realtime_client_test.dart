import 'dart:async';
import 'dart:convert';

import 'package:flutter_openai_realtime_api/flutter_openai_realtime_api.dart';
import 'package:flutter_openai_realtime_api/src/connection/realtime_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements RealtimeTransport {
  final _messages = StreamController<String>.broadcast();
  final _state = StreamController<ConnectionState>.broadcast(sync: true);
  final List<String> outbound = [];
  ConnectionState _currentState = ConnectionState.disconnected;
  bool micEnabled = true;
  bool sendShouldThrow = false;

  @override
  Stream<String> get onMessage => _messages.stream;

  @override
  Stream<ConnectionState> get onState => _state.stream;

  @override
  ConnectionState get state => _currentState;

  @override
  String? get callId => null;

  @override
  Future<void> connect() async {
    _setState(ConnectionState.connecting);
    _setState(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _setState(ConnectionState.disconnected);
  }

  @override
  Future<void> sendMessage(String rawJson) async {
    if (sendShouldThrow) throw StateError('fake transport configured to throw');
    outbound.add(rawJson);
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    micEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _state.close();
  }

  void _setState(ConnectionState s) {
    _currentState = s;
    _state.add(s);
  }

  void pushIncoming(Map<String, dynamic> event) =>
      _messages.add(jsonEncode(event));
}

RealtimeClient _newClient(FakeTransport fake) =>
    RealtimeClient.withTransport(
      const RealtimeConfig(
        apiKey: 'sk-test',
        muteStrategy: MuteStrategy.off,
      ),
      fake,
    );

void main() {
  group('RealtimeClient', () {
    test('connect drives state to connected and emits ConnectionConnected', () async {
      final fake = FakeTransport();
      final client = _newClient(fake);
      final received = <RealtimeEvent>[];
      final sub = client.events.listen(received.add);

      await client.connect();
      await Future.delayed(Duration.zero);

      expect(client.connectionState.value, ConnectionState.connected);
      expect(received.whereType<ConnectionConnected>(), hasLength(1));
      expect(fake.outbound, hasLength(1));
      final firstMsg = jsonDecode(fake.outbound.single) as Map<String, dynamic>;
      expect(firstMsg['type'], 'session.update');

      await sub.cancel();
      await client.dispose();
    });

    test('session.created sets sessionId and emits SessionCreated', () async {
      final fake = FakeTransport();
      final client = _newClient(fake);
      final received = <RealtimeEvent>[];
      final sub = client.events.listen(received.add);

      fake.pushIncoming({
        'type': 'session.created',
        'event_id': 'evt_1',
        'session': {'id': 'sess_abc', 'type': 'realtime'},
      });
      await Future.delayed(Duration.zero);

      expect(client.sessionId, 'sess_abc');
      expect(received.whereType<SessionCreated>(), hasLength(1));

      await sub.cancel();
      await client.dispose();
    });

    test('unknown event types surface as UnknownRealtimeEvent', () async {
      final fake = FakeTransport();
      final client = _newClient(fake);
      final received = <RealtimeEvent>[];
      final sub = client.events.listen(received.add);

      fake.pushIncoming({
        'type': 'made.up.event.type',
        'event_id': 'evt_2',
        'extra': 'payload',
      });
      await Future.delayed(Duration.zero);

      final unknown = received.whereType<UnknownRealtimeEvent>().toList();
      expect(unknown, hasLength(1));
      expect(unknown.single.type, 'made.up.event.type');

      await sub.cancel();
      await client.dispose();
    });

    test('sendMessage emits conversation.item.create then response.create',
        () async {
      final fake = FakeTransport();
      final client = _newClient(fake);

      await client.sendMessage('hello there');
      await Future.delayed(Duration.zero);

      expect(fake.outbound, hasLength(2));
      final first = jsonDecode(fake.outbound[0]) as Map<String, dynamic>;
      final second = jsonDecode(fake.outbound[1]) as Map<String, dynamic>;
      expect(first['type'], 'conversation.item.create');
      expect(second['type'], 'response.create');

      // The user text appears in the first message's item.content.
      final content = ((first['item'] as Map)['content'] as List).first as Map;
      expect(content['text'], 'hello there');

      await client.dispose();
    });

    test('setMuted toggles isMuted and forwards to transport', () async {
      final fake = FakeTransport();
      final client = _newClient(fake);

      expect(client.isMuted.value, isFalse);
      expect(fake.micEnabled, isTrue);

      await client.setMuted(true);
      expect(client.isMuted.value, isTrue);
      expect(fake.micEnabled, isFalse);

      await client.setMuted(false);
      expect(client.isMuted.value, isFalse);
      expect(fake.micEnabled, isTrue);

      await client.dispose();
    });

    test('dispose closes the events stream', () async {
      final fake = FakeTransport();
      final client = _newClient(fake);

      final done = client.events.drain<void>();
      await client.dispose();
      await done; // resolves only when the events stream closes

      // Subsequent dispose is a no-op.
      await client.dispose();
    });
  });
}
