/// Function tool definition.
///
/// `parameters` is a JSON Schema object describing the function's argument
/// shape. The wire format always wraps it with `"type": "function"`.
class Tool {
  /// Function name. Must be unique within the session's tool list.
  final String name;

  /// Natural-language description shown to the model so it knows when to
  /// call the function.
  final String description;

  /// JSON Schema object describing the function's argument shape.
  final Map<String, dynamic> parameters;

  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}

/// How the model should choose between tools.
sealed class ToolChoice {
  const ToolChoice();

  /// The model decides whether to call a tool.
  const factory ToolChoice.auto() = _ToolChoiceAuto;

  /// The model must not call a tool.
  const factory ToolChoice.none() = _ToolChoiceNone;

  /// The model must call exactly one tool of its choosing.
  const factory ToolChoice.required() = _ToolChoiceRequired;

  /// The model must call this specific function.
  const factory ToolChoice.function(String name) = _ToolChoiceFunction;

  Object toJson();
}

class _ToolChoiceAuto extends ToolChoice {
  const _ToolChoiceAuto();
  @override
  Object toJson() => 'auto';
}

class _ToolChoiceNone extends ToolChoice {
  const _ToolChoiceNone();
  @override
  Object toJson() => 'none';
}

class _ToolChoiceRequired extends ToolChoice {
  const _ToolChoiceRequired();
  @override
  Object toJson() => 'required';
}

class _ToolChoiceFunction extends ToolChoice {
  final String name;
  const _ToolChoiceFunction(this.name);
  @override
  Object toJson() => {
        'type': 'function',
        'function': {'name': name},
      };
}
