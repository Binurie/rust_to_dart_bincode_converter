# Rust to Dart (d_bincode) Converter

Generate Dart classes with `encode`/`decode` methods compatible with `package:d_bincode` from simple Rust struct definitions.

## Features

* Parses basic Rust `struct` definitions.
* Handles common Rust types: primitives (`u8`-`i64`, `f32`/`f64`, `bool`, `char`), `String`, `Option<T>`, `Vec<T>`, `HashSet<T>`, `HashMap<K, V>`.
* Handles fixed byte arrays `[u8; N]` (mapped to Dart `String`).
* Generates Dart classes with compatible `encode(BincodeWriter)` and `decode(BincodeReader)` methods.
* Generates an `.empty()` constructor (required convention) and a main constructor.
* Generates a basic `toString()` method.
* Handles multiple structs per input string.
* Returns a `GeneratorResult` object (`.code`, `.errors`, `.warnings`, `.notes`).

## Usage

Pass the Rust struct definition string to the generator function:

```dart
const rustInput = """
#[derive(Serialize, Deserialize)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

#[derive(Serialize, Deserialize)]
pub struct Line {
    pub start: Point,
    pub end: Option<Point>,
    pub id: [u8; 16], // Fixed bytes mapped to String
}
""";

// Generate the code
GeneratorResult result = generateDartFromRustStruct(rustInput);

if (result.hasErrors) {
  print('Errors:\n${result.errors.join('\n')}');
} else {
  print(result.code);

  // display warnings and notes
  if (result.hasWarnings) print('Warnings:\n${result.warnings.join('\n')}');
  if (result.hasNotes) print('Notes:\n${result.notes.join('\n')}');
}
```

### Output Example:

```dart
class Point implements BincodeCodable {
  int x = 0;
  int y = 0;

  Point.empty();

  Point({
    required this.x,
    required this.y,
  });

  @override
  void encode(BincodeWriter writer) {
    writer.writeI32(x);
    writer.writeI32(y);
  }

  @override
  void decode(BincodeReader reader) {
    x = reader.readI32();
    y = reader.readI32();
  }

  @override
  String toString() {
    return 'Point{x: $x, y: $y}';
  }
}

class Line implements BincodeCodable {
  Point start = Point.empty();
  Point? end;
  String id = ""; // [u8; 16] maps to String

  Line.empty();

  Line({
    required this.start,
    this.end,
    required this.id,
  });

  @override
  void encode(BincodeWriter writer) {
    writer.writeNestedValueForFixed(start);
    writer.writeOptionNestedValueForFixed(end);
    writer.writeFixedString(id, 16); // Size from Rust type
  }

  @override
  void decode(BincodeReader reader) {
    start = reader.readNestedObjectForFixed<Point>(Point.empty());
    end = reader.readOptionNestedObjectForFixed<Point>(() => Point.empty());
    id = reader.readFixedString(16); // Size from Rust type
  }

  @override
  String toString() {
    return 'Line{start: $start, end: $end, id: $id}';
  }
}
```

### `.empty()` Constructor Convention

For the generated `decode` methods to work with nested structs (like `Point` inside `Line`), the nested Dart classes (`Point` in this example) **must** provide a public, no-argument named constructor called `.empty()`. You need to ensure this convention is followed for any referenced custom types.

## Limitations

* Parses only basic Rust `struct` syntax via regular expressions.
* Does not interpret `#[serde(...)]` attributes or handle Rust enums, generics, lifetimes, etc.
* Relies on the `.empty()` constructor convention for nested types during deserialization.