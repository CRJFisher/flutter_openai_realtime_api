import 'dart:convert';

/// An item in the conversation history.
class ConversationItem {
  final String? id;
  final ConversationItemType type;
  final ConversationItemStatus? status;
  final ConversationRole? role;
  final List<ContentPart> content;

  /// Function call: server-assigned ID linking call to its output.
  final String? callId;

  /// Function call: function name.
  final String? name;

  /// Function call: JSON-encoded arguments string. The server emits this
  /// as a string, and clients should send it as a string when constructing
  /// `function_call` items (which clients rarely need to do — function
  /// calls usually come from the server).
  final String? arguments;

  /// Function call output: the function's result, JSON-encoded.
  final String? output;

  const ConversationItem({
    this.id,
    required this.type,
    this.status,
    this.role,
    this.content = const [],
    this.callId,
    this.name,
    this.arguments,
    this.output,
  });

  /// User text message.
  factory ConversationItem.userMessage({String? id, required String text}) =>
      ConversationItem(
        id: id,
        type: ConversationItemType.message,
        role: ConversationRole.user,
        content: [ContentPart.inputText(text)],
      );

  /// User image message. The image must be a base64 data URL or HTTPS URL.
  factory ConversationItem.userImage({String? id, required String imageUrl}) =>
      ConversationItem(
        id: id,
        type: ConversationItemType.message,
        role: ConversationRole.user,
        content: [ContentPart.inputImage(imageUrl)],
      );

  /// Assistant text message (use to seed history; the model will not
  /// usually need you to construct these).
  factory ConversationItem.assistantMessage({
    String? id,
    required String text,
  }) =>
      ConversationItem(
        id: id,
        type: ConversationItemType.message,
        role: ConversationRole.assistant,
        content: [ContentPart.outputText(text)],
      );

  /// System message (instructions). Use [RealtimeConfig.instructions]
  /// instead for the session-level system prompt.
  factory ConversationItem.systemMessage({String? id, required String text}) =>
      ConversationItem(
        id: id,
        type: ConversationItemType.message,
        role: ConversationRole.system,
        content: [ContentPart.inputText(text)],
      );

  /// Result of executing a function the model called. `output` should be
  /// JSON-encoded.
  factory ConversationItem.functionCallOutput({
    required String callId,
    required String output,
  }) =>
      ConversationItem(
        type: ConversationItemType.functionCallOutput,
        callId: callId,
        output: output,
      );

  /// Approval response for a hosted MCP tool call that the server requested
  /// approval for.
  factory ConversationItem.mcpApprovalResponse({
    required String approvalRequestId,
    required bool approve,
  }) =>
      ConversationItem(
        type: ConversationItemType.mcpApprovalResponse,
        // We reuse `name` to carry the approval-request id; the JSON
        // serializer remaps it.
        name: approvalRequestId,
        // and `output` to carry the boolean.
        output: approve.toString(),
      );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type.id};
    if (id != null) json['id'] = id;
    if (status != null) json['status'] = status!.id;

    switch (type) {
      case ConversationItemType.message:
        if (role != null) json['role'] = role!.id;
        if (content.isNotEmpty) {
          json['content'] = content.map((c) => c.toJson()).toList();
        }
        break;
      case ConversationItemType.functionCall:
        if (name != null) json['name'] = name;
        if (callId != null) json['call_id'] = callId;
        if (arguments != null) json['arguments'] = arguments;
        break;
      case ConversationItemType.functionCallOutput:
        if (callId != null) json['call_id'] = callId;
        if (output != null) json['output'] = output;
        break;
      case ConversationItemType.mcpApprovalResponse:
        if (name != null) json['approval_request_id'] = name;
        if (output != null) json['approve'] = output == 'true';
        break;
    }
    return json;
  }

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final typeId = json['type'] as String?;
    final type = ConversationItemType.fromId(typeId);
    final argsRaw = json['arguments'];
    return ConversationItem(
      id: json['id'] as String?,
      type: type,
      status: ConversationItemStatus.fromId(json['status'] as String?),
      role: ConversationRole.fromId(json['role'] as String?),
      content: (json['content'] as List<dynamic>?)
              ?.map((c) => ContentPart.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: argsRaw is String
          ? argsRaw
          : argsRaw is Map
              ? jsonEncode(argsRaw)
              : null,
      output: json['output'] as String?,
    );
  }
}

/// Wire-level item type. Drives JSON serialisation.
enum ConversationItemType {
  /// A regular conversation message (user, assistant, or system).
  message('message'),

  /// A model-emitted request to invoke a tool/function.
  functionCall('function_call'),

  /// The client's reply to a [functionCall].
  functionCallOutput('function_call_output'),

  /// The client's reply to a hosted MCP approval request.
  mcpApprovalResponse('mcp_approval_response');

  const ConversationItemType(this.id);
  final String id;

  /// Returns [ConversationItemType.message] for unknown values rather than
  /// throwing, to keep us forward-compatible with new item types.
  static ConversationItemType fromId(String? id) {
    if (id == null) return ConversationItemType.message;
    for (final t in values) {
      if (t.id == id) return t;
    }
    return ConversationItemType.message;
  }
}

/// Lifecycle status of a [ConversationItem] as reported by the server.
enum ConversationItemStatus {
  /// The item is still streaming in.
  inProgress('in_progress'),

  /// The item has finished and is in its final form.
  completed('completed'),

  /// The item finished early (e.g. truncation, max_output_tokens).
  incomplete('incomplete');

  const ConversationItemStatus(this.id);
  final String id;

  static ConversationItemStatus? fromId(String? id) {
    if (id == null) return null;
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Author role for a message-type conversation item.
enum ConversationRole {
  /// The end user of the application.
  user('user'),

  /// The model.
  assistant('assistant'),

  /// System-level instructions.
  system('system');

  const ConversationRole(this.id);
  final String id;

  static ConversationRole? fromId(String? id) {
    if (id == null) return null;
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// One part of the structured content of a conversation message item.
class ContentPart {
  final ContentType type;
  final String? text;
  final String? audio;
  final String? transcript;
  final String? imageUrl;

  const ContentPart({
    required this.type,
    this.text,
    this.audio,
    this.transcript,
    this.imageUrl,
  });

  factory ContentPart.inputText(String text) =>
      ContentPart(type: ContentType.inputText, text: text);
  factory ContentPart.inputAudio({required String audio, String? transcript}) =>
      ContentPart(
          type: ContentType.inputAudio, audio: audio, transcript: transcript);
  factory ContentPart.inputImage(String imageUrl) =>
      ContentPart(type: ContentType.inputImage, imageUrl: imageUrl);

  /// Output text from the assistant (GA name).
  factory ContentPart.outputText(String text) =>
      ContentPart(type: ContentType.outputText, text: text);
  factory ContentPart.outputAudio({String? audio, String? transcript}) =>
      ContentPart(
        type: ContentType.outputAudio,
        audio: audio,
        transcript: transcript,
      );

  Map<String, dynamic> toJson() => {
        'type': type.id,
        if (text != null) 'text': text,
        if (audio != null) 'audio': audio,
        if (transcript != null) 'transcript': transcript,
        if (imageUrl != null) 'image_url': imageUrl,
      };

  factory ContentPart.fromJson(Map<String, dynamic> json) {
    return ContentPart(
      type: ContentType.fromId(json['type'] as String?),
      text: json['text'] as String?,
      audio: json['audio'] as String?,
      transcript: json['transcript'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// Wire-level type tag for a [ContentPart].
enum ContentType {
  /// Pre-GA assistant output text. Treat as equivalent to [outputText].
  text('text'),

  /// User-supplied text.
  inputText('input_text'),

  /// User-supplied audio (base64 PCM).
  inputAudio('input_audio'),

  /// User-supplied image (data URL or HTTPS URL).
  inputImage('input_image'),

  /// Assistant text output.
  outputText('output_text'),

  /// Assistant audio output.
  outputAudio('output_audio'),

  /// Unknown / unrecognised content type.
  unknown('');

  const ContentType(this.id);
  final String id;

  static ContentType fromId(String? id) {
    if (id == null) return ContentType.unknown;
    for (final t in values) {
      if (t.id == id) return t;
    }
    return ContentType.unknown;
  }
}
