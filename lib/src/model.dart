class FieldInfo {
  final String rustName;
  final String rustType;
  final String dartName;
  final String dartType;
  final bool isNullable;
  final int? fixedSize;

  FieldInfo({
    required this.rustName,
    required this.rustType,
    required this.dartName,
    required this.dartType,
    required this.isNullable,
    this.fixedSize,
  });
}

typedef DartTypeInfo = ({String dartType, bool isNullable});
