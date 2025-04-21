import 'model.dart';
import 'type_mapping.dart';

/// Generates the `writer.writeXXX(...)` call string for a field.
String getBincodeWriterCall(FieldInfo field) {
  final fieldAccess = field.dartName;

  // Handle Option<T>
  if (field.isNullable) {
    if (field.fixedSize != null && field.dartType == 'String') {
      return "writer.writeOptionFixedString($fieldAccess, ${field.fixedSize}); // Size from Rust type";
    }

    final innerRustType =
        RegExp(
          r'^Option\s*<\s*(.+)\s*>$',
        ).firstMatch(field.rustType)?.group(1)?.trim() ??
        '';
    if (innerRustType.isEmpty) {
      return "// Error writing Option type for ${field.dartName}";
    }
    final writerMethod = getPrimitiveOrSpecialWriterMethodName(
      innerRustType,
      optional: true,
    );
    if (writerMethod != null) {
      return "writer.$writerMethod($fieldAccess);";
    }
    return "writer.writeOptionNestedValueForFixed($fieldAccess);";
  }

  // Handle Vec<T>
  final vecMatch = RegExp(r'^Vec\s*<\s*(.+)\s*>$').firstMatch(field.rustType);
  if (vecMatch != null) {
    final innerRustType = vecMatch.group(1)!.trim();
    final specializedListWriter = getSpecializedListWriterMethodName(
      innerRustType,
    );
    if (specializedListWriter != null) {
      return "writer.$specializedListWriter($fieldAccess);";
    }
    final innerDartType = mapRustTypeToDart(innerRustType).dartType;
    final innerWriterCall = getBincodeWriterLambdaBody(
      innerRustType,
      'v',
      innerDartType,
    );
    return "writer.writeList<$innerDartType>($fieldAccess, ($innerDartType v) => $innerWriterCall);";
  }

  // Handle HashSet<T>
  final setMatch = RegExp(
    r'^HashSet\s*<\s*(.+)\s*>$',
  ).firstMatch(field.rustType);
  if (setMatch != null) {
    final innerRustType = setMatch.group(1)!.trim();
    final innerDartType = mapRustTypeToDart(innerRustType).dartType;
    final innerWriterCall = getBincodeWriterLambdaBody(
      innerRustType,
      'v',
      innerDartType,
    );
    return "writer.writeSet<$innerDartType>($fieldAccess, ($innerDartType v) => $innerWriterCall);";
  }

  // Handle HashMap<K, V>
  final mapMatch = RegExp(
    r'^HashMap\s*<\s*(.+?)\s*,\s*(.+?)\s*>$',
  ).firstMatch(field.rustType);
  if (mapMatch != null) {
    final keyRustType = mapMatch.group(1)!.trim();
    final valueRustType = mapMatch.group(2)!.trim();
    final keyDartType = mapRustTypeToDart(keyRustType).dartType;
    final valueDartType = mapRustTypeToDart(valueRustType).dartType;
    final keyWriterCall = getBincodeWriterLambdaBody(
      keyRustType,
      'k',
      keyDartType,
    );
    final valueWriterCall = getBincodeWriterLambdaBody(
      valueRustType,
      'v',
      valueDartType,
    );
    return "writer.writeMap<$keyDartType, $valueDartType>($fieldAccess, ($keyDartType k) => $keyWriterCall, ($valueDartType v) => $valueWriterCall);";
  }

  // Handle Primitives / Strings (including [u8; N]) / Special Types (non-optional)
  if (field.fixedSize != null && field.dartType == 'String') {
    return "writer.writeFixedString($fieldAccess, ${field.fixedSize}); // Size from Rust type";
  }
  final writerMethod = getPrimitiveOrSpecialWriterMethodName(
    field.rustType,
    optional: false,
  );
  if (writerMethod != null) {
    return "writer.$writerMethod($fieldAccess);";
  }
  return "writer.writeNestedValueForFixed($fieldAccess);";
}

String? getPrimitiveOrSpecialWriterMethodName(
  String rustType, {
  required bool optional,
}) {
  final prefix = optional ? "writeOption" : "write";
  switch (rustType) {
    case 'u8':
      return '${prefix}U8';
    case 'i8':
      return '${prefix}I8';
    case 'u16':
      return '${prefix}U16';
    case 'i16':
      return '${prefix}I16';
    case 'u32':
      return '${prefix}U32';
    case 'i32':
      return '${prefix}I32';
    case 'u64':
      return '${prefix}U64';
    case 'i64':
      return '${prefix}I64';
    case 'usize':
      return '${prefix}U64';
    case 'isize':
      return '${prefix}I64';
    case 'f32':
      return '${prefix}F32';
    case 'f64':
      return '${prefix}F64';
    case 'bool':
      return '${prefix}Bool';
    case 'String':
      return '${prefix}String';
    case 'char':
      return '${prefix}Char';
    case 'Duration':
      return '${prefix}Duration';
    default:
      return null;
  }
}

String? getPrimitiveOrSpecialReaderMethodName(
  String rustType, {
  required bool optional,
}) {
  final prefix = optional ? "readOption" : "read";
  switch (rustType) {
    case 'u8':
      return '${prefix}U8';
    case 'i8':
      return '${prefix}I8';
    case 'u16':
      return '${prefix}U16';
    case 'i16':
      return '${prefix}I16';
    case 'u32':
      return '${prefix}U32';
    case 'i32':
      return '${prefix}I32';
    case 'u64':
      return '${prefix}U64';
    case 'i64':
      return '${prefix}I64';
    case 'usize':
      return '${prefix}U64';
    case 'isize':
      return '${prefix}I64';
    case 'f32':
      return '${prefix}F32';
    case 'f64':
      return '${prefix}F64';
    case 'bool':
      return '${prefix}Bool';
    case 'String':
      return '${prefix}String';
    case 'char':
      return '${prefix}Char';
    case 'Duration':
      return '${prefix}Duration';
    default:
      return null;
  }
}

String? getSpecializedListWriterMethodName(String innerRustType) {
  switch (innerRustType) {
    case 'u8':
      return 'writeUint8List';
    case 'i8':
      return 'writeInt8List';
    case 'u16':
      return 'writeUint16List';
    case 'i16':
      return 'writeInt16List';
    case 'u32':
      return 'writeUint32List';
    case 'i32':
      return 'writeInt32List';
    case 'u64':
      return 'writeUint64List';
    case 'i64':
      return 'writeInt64List';
    case 'f32':
      return 'writeFloat32List';
    case 'f64':
      return 'writeFloat64List';
    default:
      return null;
  }
}

String? getSpecializedListReaderMethodName(String innerRustType) {
  switch (innerRustType) {
    case 'u8':
      return 'readUint8List';
    case 'i8':
      return 'readInt8List';
    case 'u16':
      return 'readUint16List';
    case 'i16':
      return 'readInt16List';
    case 'u32':
      return 'readUint32List';
    case 'i32':
      return 'readInt32List';
    case 'u64':
      return 'readUint64List';
    case 'i64':
      return 'readInt64List';
    case 'f32':
      return 'readFloat32List';
    case 'f64':
      return 'readFloat64List';
    default:
      return null;
  }
}

String getBincodeWriterLambdaBody(
  String innerRustType,
  String varName,
  String innerDartType,
) {
  final writerMethod = getPrimitiveOrSpecialWriterMethodName(
    innerRustType,
    optional: false,
  );
  if (writerMethod != null) {
    return "writer.$writerMethod($varName)";
  }
  return "writer.writeNestedValueForFixed($varName)";
}

/// Generates the body of the lambda function for reading an inner element
/// for methods like readList, readSet, readMap.
String getBincodeReaderLambdaBody(String innerRustType) {
  final readerMethod = getPrimitiveOrSpecialReaderMethodName(
    innerRustType,
    optional: false,
  );
  if (readerMethod != null) {
    return "reader.$readerMethod()";
  }

  final innerDartType = mapRustTypeToDart(innerRustType).dartType;

  return "reader.readNestedObjectForFixed<$innerDartType>($innerDartType.empty())";
}

// --- Make sure getBincodeReaderAssignment is correct ---
String getBincodeReaderAssignment(FieldInfo field) {
  final assignmentTarget = "${field.dartName} =";

  // Handle Option<T>
  if (field.isNullable) {
    // Check if it was Option<[u8; N]> -> String? with fixedSize
    if (field.fixedSize != null && field.dartType == 'String') {
      return "$assignmentTarget reader.readOptionFixedString(${field.fixedSize});";
    }
    // Handle regular Option<Primitive/String/Duration or Custom>
    final innerRustType =
        RegExp(
          r'^Option\s*<\s*(.+)\s*>$',
        ).firstMatch(field.rustType)?.group(1)?.trim() ??
        '';
    if (innerRustType.isEmpty) {
      return "// Error reading Option type for ${field.dartName}";
    }
    final readerMethod = getPrimitiveOrSpecialReaderMethodName(
      innerRustType,
      optional: true,
    );
    if (readerMethod != null) {
      return "$assignmentTarget reader.$readerMethod();";
    }
    final innerDartType = mapRustTypeToDart(innerRustType).dartType;
    return "$assignmentTarget reader.readOptionNestedObjectForFixed<$innerDartType>(() => $innerDartType.empty());";
  }

  // --- Handle Non-Nullable Types ---

  // Handle Vec<T>
  final vecMatch = RegExp(r'^Vec\s*<\s*(.+)\s*>$').firstMatch(field.rustType);
  if (vecMatch != null) {
    final innerRustType = vecMatch.group(1)!.trim();
    final specializedListReader = getSpecializedListReaderMethodName(
      innerRustType,
    );
    if (specializedListReader != null) {
      if (field.rustName.contains("fixed")) {
        print(
          "// NOTE: Fixed array handling for ${field.dartName} relies on Bincode library's implementation of $specializedListReader.",
        );
      }
      return "$assignmentTarget reader.$specializedListReader();";
    }
    final innerDartType = mapRustTypeToDart(innerRustType).dartType;
    // The lambda body will now be correct via getBincodeReaderLambdaBody
    final innerReaderCall = getBincodeReaderLambdaBody(innerRustType);
    if (field.rustName.contains("fixed")) {
      print(
        "// NOTE: Fixed array handling for ${field.dartName} relies on Bincode library's implementation of readList.",
      );
    }
    return "$assignmentTarget reader.readList<$innerDartType>(() => $innerReaderCall);";
  }

  // Handle HashSet<T>
  final setMatch = RegExp(
    r'^HashSet\s*<\s*(.+)\s*>$',
  ).firstMatch(field.rustType);
  if (setMatch != null) {
    final innerRustType = setMatch.group(1)!.trim();
    final innerDartType = mapRustTypeToDart(innerRustType).dartType;
    final innerReaderCall = getBincodeReaderLambdaBody(innerRustType);
    return "$assignmentTarget reader.readSet<$innerDartType>(() => $innerReaderCall);";
  }

  // Handle HashMap<K, V>
  final mapMatch = RegExp(
    r'^HashMap\s*<\s*(.+?)\s*,\s*(.+?)\s*>$',
  ).firstMatch(field.rustType);
  if (mapMatch != null) {
    final keyRustType = mapMatch.group(1)!.trim();
    final valueRustType = mapMatch.group(2)!.trim();
    final keyDartType = mapRustTypeToDart(keyRustType).dartType;
    final valueDartType = mapRustTypeToDart(valueRustType).dartType;
    final keyReaderCall = getBincodeReaderLambdaBody(keyRustType);
    final valueReaderCall = getBincodeReaderLambdaBody(valueRustType);
    return "$assignmentTarget reader.readMap<$keyDartType, $valueDartType>(() => $keyReaderCall, () => $valueReaderCall);";
  }

  // Handle Primitives / Strings (including [u8; N]) / Special Types (non-optional)
  if (field.fixedSize != null && field.dartType == 'String') {
    return "$assignmentTarget reader.readFixedString(${field.fixedSize});";
  }
  final readerMethod = getPrimitiveOrSpecialReaderMethodName(
    field.rustType,
    optional: false,
  );
  if (readerMethod != null) {
    return "$assignmentTarget reader.$readerMethod();";
  }
  return "$assignmentTarget reader.readNestedObjectForFixed<${field.dartType}>(${field.dartType}.empty());";
}
