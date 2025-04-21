import 'model.dart';

/// Maps a Rust type string to its Dart equivalent and nullability.
DartTypeInfo mapRustTypeToDart(String rustType) {
  rustType = rustType.trim();

  // Handle Option<T> (excluding Option<[u8;N]>)
  final optionMatch = RegExp(r'^Option\s*<\s*(.+)\s*>$').firstMatch(rustType);
  if (optionMatch != null) {
    final innerType = optionMatch.group(1)!.trim();
    if (innerType.startsWith('Option<') || innerType.startsWith('[')) {
      throw FormatException(
        "Unsupported nested Option/Array type passed to mapRustTypeToDart: $rustType",
      );
    }
    final innerDartType = mapRustTypeToDart(innerType);
    return (dartType: innerDartType.dartType, isNullable: true);
  }
  // Handle Vec<T>
  final vecMatch = RegExp(r'^Vec\s*<\s*(.+)\s*>$').firstMatch(rustType);
  if (vecMatch != null) {
    final innerType = vecMatch.group(1)!.trim();
    final innerDartType = mapRustTypeToDart(innerType);
    return (dartType: 'List<${innerDartType.dartType}>', isNullable: false);
  }
  // Handle HashSet<T>
  final setMatch = RegExp(r'^HashSet\s*<\s*(.+)\s*>$').firstMatch(rustType);
  if (setMatch != null) {
    final innerType = setMatch.group(1)!.trim();
    final innerDartType = mapRustTypeToDart(innerType);
    return (dartType: 'Set<${innerDartType.dartType}>', isNullable: false);
  }
  // Handle HashMap<K, V>
  final mapMatch = RegExp(
    r'^HashMap\s*<\s*(.+?)\s*,\s*(.+?)\s*>$',
  ).firstMatch(rustType);
  if (mapMatch != null) {
    final keyType = mapMatch.group(1)!.trim();
    final valueType = mapMatch.group(2)!.trim();
    final keyDartType = mapRustTypeToDart(keyType);
    final valueDartType = mapRustTypeToDart(valueType);
    return (
      dartType: 'Map<${keyDartType.dartType}, ${valueDartType.dartType}>',
      isNullable: false,
    );
  }
  // Handle Primitive Types
  switch (rustType) {
    case 'u8':
    case 'i8':
    case 'u16':
    case 'i16':
    case 'u32':
    case 'i32':
    case 'u64':
    case 'i64':
    case 'usize':
    case 'isize':
      return (dartType: 'int', isNullable: false);
    case 'f32':
    case 'f64':
      return (dartType: 'double', isNullable: false);
    case 'bool':
      return (dartType: 'bool', isNullable: false);
    case 'String':
    case 'char':
      return (dartType: 'String', isNullable: false);
    case 'Duration':
      return (dartType: 'Duration', isNullable: false);
  }

  final simpleTypeName = rustType.split('::').last;
  return (dartType: simpleTypeName, isNullable: false);
}

String getDefaultValue(String dartType) {
  if (dartType.startsWith('List<')) return '[]';
  if (dartType.startsWith('Set<')) return '{}';
  if (dartType.startsWith('Map<')) return '{}';
  switch (dartType) {
    case 'int':
      return '0';
    case 'double':
      return '0.0';
    case 'bool':
      return 'false';
    case 'String':
      return '""';
    case 'Duration':
      return 'Duration.zero';
    default:
      return '$dartType.empty()';
  }
}

bool isCustomType(String rustType) {
  String currentType = rustType.trim();

  bool changed = true;
  while (changed) {
    changed = false;
    final optMatch = RegExp(r'^Option\s*<\s*(.+)\s*>$').firstMatch(currentType);
    if (optMatch != null) {
      currentType = optMatch.group(1)!.trim();
      if (currentType.startsWith('[')) return false;
      changed = true;
      continue;
    }
    final vecMatch = RegExp(r'^Vec\s*<\s*(.+)\s*>$').firstMatch(currentType);
    if (vecMatch != null) {
      currentType = vecMatch.group(1)!.trim();
      changed = true;
      continue;
    }
    final setMatch = RegExp(
      r'^HashSet\s*<\s*(.+)\s*>$',
    ).firstMatch(currentType);
    if (setMatch != null) {
      currentType = setMatch.group(1)!.trim();
      changed = true;
      continue;
    }
    final mapMatch = RegExp(
      r'^HashMap\s*<\s*.+?\s*,\s*(.+?)\s*>$',
    ).firstMatch(currentType);
    if (mapMatch != null) {
      currentType = mapMatch.group(1)!.trim();
      changed = true;
      continue;
    }
  }

  if (currentType.startsWith('[')) return false;

  switch (currentType) {
    case 'u8':
    case 'i8':
    case 'u16':
    case 'i16':
    case 'u32':
    case 'i32':
    case 'u64':
    case 'i64':
    case 'usize':
    case 'isize':
    case 'f32':
    case 'f64':
    case 'bool':
    case 'String':
    case 'char':
    case 'Duration':
      return false;
    default:
      return currentType.isNotEmpty;
  }
}
