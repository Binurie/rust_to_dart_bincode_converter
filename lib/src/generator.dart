import 'package:recase/recase.dart';
import 'package:rust_to_dart_bincode_converter/src/generator_results.dart';

import 'bincode_helpers.dart';
import 'model.dart';
import 'type_mapping.dart';

GeneratorResult generateDartFromRustStruct(String rustCode) {
  final structRegex = RegExp(
    r'struct\s+(\w+)\s*\{((?:[^{}]|\{[^{}]*\})*)\}',
    multiLine: true,
  );

  final List<String> allGeneratedClasses = [];
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> notes = [];
  int structCount = 0;

  final List<FieldInfo> allParsedFields = [];

  for (final match in structRegex.allMatches(rustCode)) {
    structCount++;
    final structName = match.group(1);
    final fieldsBlock = match.group(2);

    if (structName == null || fieldsBlock == null) {
      warnings.add(
        "Warning: Failed to parse structure name or body near '${match.input.substring(match.start, match.end > match.start + 50 ? match.start + 50 : match.end)}...'",
      );
      continue;
    }

    final List<FieldInfo> currentStructParsedFields = [];
    final List<String> currentStructDartDeclarations = [];
    final List<String> currentStructErrors = [];
    final fieldLines = fieldsBlock.split('\n');
    final fieldRegex = RegExp(
      r'^\s*(?:pub\s+)?(\w+)\s*:\s*(.+?)\s*,?\s*(?://.*)?$',
    );
    final fixedArrayRegex = RegExp(r'^\[\s*u8\s*;\s*(\d+)\s*\]$');
    final optFixedArrayRegex = RegExp(
      r'^Option\s*<\s*\[\s*u8\s*;\s*(\d+)\s*\]\s*>$',
    );

    int lineNum = 0;
    for (final line in fieldLines) {
      lineNum++;
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('//') ||
          trimmedLine.startsWith('#[')) {
        continue;
      }

      final fieldMatch = fieldRegex.firstMatch(trimmedLine);
      if (fieldMatch != null) {
        final rustFieldName = fieldMatch.group(1)!;
        final fullRustTypeString = fieldMatch.group(2)!.trim();
        final dartFieldName = ReCase(rustFieldName).camelCase;
        DartTypeInfo dartTypeInfo;
        int? fixedSize;

        try {
          final optFixedMatch = optFixedArrayRegex.firstMatch(
            fullRustTypeString,
          );
          final fixedMatch = fixedArrayRegex.firstMatch(fullRustTypeString);

          if (optFixedMatch != null) {
            final sizeStr = optFixedMatch.group(1)!;
            fixedSize = int.tryParse(sizeStr);
            if (fixedSize == null) {
              throw FormatException("Invalid size in Option<[u8; N]>");
            }
            dartTypeInfo = (dartType: 'String', isNullable: true);
          } else if (fixedMatch != null) {
            final sizeStr = fixedMatch.group(1)!;
            fixedSize = int.tryParse(sizeStr);
            if (fixedSize == null) {
              throw FormatException("Invalid size in [u8; N]");
            }
            dartTypeInfo = (dartType: 'String', isNullable: false);
          } else {
            dartTypeInfo = mapRustTypeToDart(fullRustTypeString);
            fixedSize = null;
          }

          final fieldInfo = FieldInfo(
            rustName: rustFieldName,
            rustType: fullRustTypeString,
            dartName: dartFieldName,
            dartType: dartTypeInfo.dartType,
            isNullable: dartTypeInfo.isNullable,
            fixedSize: fixedSize,
          );
          currentStructParsedFields.add(fieldInfo);

          String fieldDeclaration;
          if (fieldInfo.isNullable) {
            fieldDeclaration =
                "  ${fieldInfo.dartType}? ${fieldInfo.dartName};";
          } else {
            final defaultValue = getDefaultValue(fieldInfo.dartType);
            fieldDeclaration =
                "  ${fieldInfo.dartType} ${fieldInfo.dartName} = $defaultValue;";
          }
          currentStructDartDeclarations.add(fieldDeclaration);
        } catch (e) {
          final errorMsg =
              "Error processing line $lineNum in struct '$structName': '$trimmedLine' - $e";
          print("// $errorMsg");
          currentStructErrors.add(errorMsg);
        }
      } else {
        warnings.add(
          "Warning: Could not parse field line $lineNum in struct '$structName': $trimmedLine",
        );
      }
    }

    if (currentStructErrors.isNotEmpty) {
      errors.addAll(currentStructErrors);
      continue;
    }

    allParsedFields.addAll(currentStructParsedFields);

    final encodeLines =
        currentStructParsedFields.map((f) => getBincodeWriterCall(f)).toList();
    final decodeLines =
        currentStructParsedFields
            .map((f) => getBincodeReaderAssignment(f))
            .toList();
    final encodeMethod =
        "  @override\n  void encode(BincodeWriter writer) {\n${encodeLines.map((l) => "    $l").join('\n')}\n  }";
    final decodeMethod =
        "  @override\n  void decode(BincodeReader reader) {\n${decodeLines.map((l) => "    $l").join('\n')}\n  }";
    final toStringMethod = _buildToStringMethod(
      structName,
      currentStructParsedFields,
    ); // Use current fields
    final fieldsString = currentStructDartDeclarations.join('\n');
    final constructorParams = currentStructParsedFields
        .map((f) {
          final req = f.isNullable ? '' : 'required ';
          return '    ${req}this.${f.dartName},';
        })
        .join('\n');
    final classString = """
class $structName implements BincodeCodable {
$fieldsString

  $structName.empty();

  $structName({
$constructorParams
  });

$encodeMethod

$decodeMethod

$toStringMethod
}
""";
    allGeneratedClasses.add(classString);
  }

  if (structCount == 0 && errors.isEmpty && warnings.isEmpty) {
    return GeneratorResult(
      code: '',
      errors: ["No struct definitions found in input."],
    );
  }

  final Set<String> customTypeNames = {};
  allParsedFields.where((f) => isCustomType(f.rustType)).forEach((f) {
    String baseType = f.dartType;
    if (baseType.contains('<')) {
      baseType = baseType.substring(0, baseType.indexOf('<'));
    }
    if (baseType != 'List' &&
        baseType != 'Set' &&
        baseType != 'Map' &&
        baseType != 'String' &&
        baseType != 'int' &&
        baseType != 'double' &&
        baseType != 'bool' &&
        baseType != 'Duration') {
      customTypeNames.add(baseType);
    }
  });

  if (customTypeNames.isNotEmpty) {
    notes.add(
      'IMPORTANT: Ensure the following classes are defined, implement BincodeCodable, and have an `.empty()` constructor: ${customTypeNames.join(', ')}',
    );
  }
  notes.add(
    "NOTE: Sizes for fixed string methods are derived directly from Rust's [u8; N] syntax.",
  );

  final codeResult = allGeneratedClasses.join('\n\n');
  final finalCode = '''


${codeResult.trim()}
''';

  return GeneratorResult(
    code: finalCode.trim(),
    errors: errors,
    warnings: warnings,
    notes: notes,
  );
}

String _buildToStringMethod(String className, List<FieldInfo> fields) {
  final fieldStrings = fields.map((f) => '${f.dartName}: \$${f.dartName}');
  final content = fieldStrings.join(', ');
  return """
  @override
  String toString() {
    return '$className{$content}';
  }
""";
}
