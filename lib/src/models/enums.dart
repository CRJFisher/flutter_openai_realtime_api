/// Voice for assistant audio output.
///
/// `marin` and `cedar` are exclusive to `gpt-realtime`. The other voices work
/// with all current Realtime models.
enum Voice {
  alloy('alloy'),
  ash('ash'),
  ballad('ballad'),
  coral('coral'),
  echo('echo'),
  sage('sage'),
  shimmer('shimmer'),
  verse('verse'),
  marin('marin'),
  cedar('cedar');

  const Voice(this.id);
  final String id;
}

/// Modalities the model is allowed to produce.
enum Modality {
  text('text'),
  audio('audio');

  const Modality(this.id);
  final String id;
}

/// Audio formats accepted on the WebSocket transport.
///
/// Has no effect on WebRTC: media there is always Opus 48 kHz over the audio
/// track, and `output_audio_format` / `input_audio_format` are ignored by the
/// server when using `/v1/realtime/calls`.
enum AudioFormat {
  /// 16-bit signed PCM, little-endian, 24 kHz, mono, raw (no header).
  pcm16('pcm16'),

  /// G.711 µ-law at 8 kHz mono.
  g711Ulaw('g711_ulaw'),

  /// G.711 A-law at 8 kHz mono.
  g711Alaw('g711_alaw');

  const AudioFormat(this.id);
  final String id;
}
