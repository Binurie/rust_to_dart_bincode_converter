class GeneratorResult {
  final String code;

  final List<String> errors;

  final List<String> warnings;

  final List<String> notes;

  GeneratorResult({
    required this.code,
    this.errors = const [],
    this.warnings = const [],
    this.notes = const [],
  });

  bool get hasErrors => errors.isNotEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasNotes => notes.isNotEmpty;
}
