/// Models supported for input audio transcription.
enum TranscriptionModel {
  whisper1('whisper-1'),
  gpt4oTranscribe('gpt-4o-transcribe'),
  gpt4oMiniTranscribe('gpt-4o-mini-transcribe');

  const TranscriptionModel(this.id);
  final String id;
}

/// Configuration for transcribing the user's input audio. When set, the
/// server emits `conversation.item.input_audio_transcription.completed`
/// events containing the recognised text.
class TranscriptionConfig {
  /// ISO-639-1 language code. Improves accuracy and latency when the input
  /// language is known in advance.
  final String? language;

  final TranscriptionModel model;

  /// Optional prompt to bias the recogniser. For `whisper-1` this is a
  /// list of keywords; for the gpt-4o transcribe models it is free text.
  final String? prompt;

  const TranscriptionConfig({
    this.language,
    this.prompt,
    this.model = TranscriptionModel.whisper1,
  });

  Map<String, dynamic> toJson() => {
    'model': model.id,
    if (language != null) 'language': language,
    if (prompt != null) 'prompt': prompt,
  };
}
