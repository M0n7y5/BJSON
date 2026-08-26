# Changelog

## v2.0.0

### Breaking Changes

- `IJsonSerializable.JsonDeserialize` returns `Result<void, JsonDeserializationError>` instead of a bare `Result<void>`. Types carrying an emitted deserializer only need a rebuild; a hand written implementation has to widen its signature
- The four typed `Json.Deserialize<T>` overloads (`Stream` and `StringView`, filling and allocating) return `Result<_, JsonDeserializationError>` instead of `Result<_, JsonParsingError>`. A parse failure arrives as `.ParseError(inner)`, and a binding failure carries the field that failed instead of collapsing into `.InvalidDocument`. The DOM `Json.Deserialize` overloads are unchanged
- `JsonDeserializationError` is now the error the emitted code raises, and every payload is a literal baked in at emit time: `TypeMismatch(path, expected, actual)`, `MissingRequiredField(path, fieldName)`, `InvalidEnumValue(path, enumType)`, `ConverterFailed(path)`, and `ParseError(inner)`. `path` is `/jsonName` on the type that reported the error, so an error from a nested `[JsonObject]` field is relative to that type. `NullNotAllowed` and `UnknownField` are removed, since a JSON null leaves a field untouched by design and there is no strict unknown field mode, and `InvalidEnumValue` and `ConverterFailed` dropped the payloads that would have aliased the parsed document
- `IJsonSerializable.JsonSerialize` and the four typed `Json.Serialize<T>` overloads (`Stream` and `String` buffer, each with and without `JsonWriterOptions`) return `Result<void, JsonSerializationError>` instead of a bare `Result<void>`, so a typed write reports the detail the DOM writer already reported. Types carrying an emitted serializer only need a rebuild; a hand written implementation has to widen its signature. The DOM `Json.Serialize` overloads are unchanged
- Added `JsonSerializationError.ConverterFailed`, which the emitted serializer returns when an `IJsonConverter.WriteJson` refuses the value it was handed. `IJsonConverter` still reports no reason of its own, so its `WriteJson` and `ReadJson` signatures are unchanged

### New Features

- Added `Json.Deserialize<T>(StringView)` and `Json.Deserialize<T>(StringView, T)`, so typed deserialization no longer requires wrapping the text in a `StringStream`
- Added `JsonValue.TypeName()`, which names the JSON type a value holds and supplies the `actual` side of a type mismatch report
- `Dictionary<String, TEnum>` fields and `String[N]` and `TEnum[N]` sized arrays now deserialize; an enum reads from either a string or a number, as an enum field already did
- A `[JsonConverter]` on a type is now honoured on a plain field of that type. A field needs the attribute only to override the converter its own type declares
- `BJSON.SchemaCodeGen` emits fields in the order the document declares them instead of in hash order, so a regenerated file is byte identical, and an inline `allOf` member whose properties the deriving type absorbed no longer gets a file of its own
- Added `[JsonExtensionData]`: one `Dictionary<String, T>` field per type captures every JSON property that matches no declared field and writes its entries back on serialization
- `BJSON.SchemaCodeGen` now resolves `$defs` and local file `$ref` targets, understands `$id` and `$anchor`, generates array types, and maps `additionalProperties` onto `[JsonExtensionData]`
- Added a warnings-as-errors mode to `BJSON.SchemaCodeGen` for schemas that use keywords the generator does not support
- Added the `BJSON.SchemaCodeGen.Tests` project, which exercises the generator against its schema corpus

### Bug Fixes

- Fixed the emitters skipping a field they could not handle: an unsupported field, element, dictionary value, or sized array element now fails generation naming the field and the type instead of emitting a read that silently does nothing
- Fixed a `StringView` field reaching the emitters, which produced code that cannot own the text a read produces. Validation now rejects it at comptime and names `String` as the fix
- Fixed schema error pointers for `not` and `if` subschemas omitting the keyword segment, so two different subschemas reported the same location
- Fixed the schema CLI emitting enum member names and duplicate property names verbatim, which produced files that do not compile
- Fixed a multi line schema `description` breaking the generated file it was written into
- Removed the orphaned `EmployeeBase1.bf` from the checked in generated output
- Fixed `BJSON.Example` discarding `Result` values, which traps at runtime in a Beef build with checks enabled

---

## v1.3.1

### Bug Fixes

- Fixed `GetOrDefault<StringView>()` on objects returning a dangling view for SSO strings: the value was copied out of the dictionary, so the view referenced a dead temporary
- Fixed `GetByPointerOrDefault<StringView>()` returning a dangling view for SSO strings: pointer resolution now walks to the stored value instead of copying it
- Fixed `BJSON.SchemaCodeGen` failing to compile: `FileWriteError` was ambiguous with `System.IO.FileWriteError`
- Fixed a one byte stack overflow when writing doubles: `dtoa` needs 26 bytes for its longest output plus terminator, the writer supplied 25. The writer now uses the length `dtoa` returns instead of scanning for the terminator
- Fixed `JsonObject`'s key indexer storing a key it does not own: `Dispose` then freed caller memory, including string literals. The indexer now copies the key, and both container indexers dispose the value they replace instead of leaking it
- Fixed parse errors carrying a `StringView` into a dead stack allocation, so `JsonParsingError.ToString` printed reclaimed memory
- Fixed valid documents with about 200 or more empty objects or arrays being rejected with `MaximumDepthReached`: the empty container fast path never decremented the depth counter
- Fixed the real parse error being replaced by a trailing data error whenever parsing stopped before the end of input
- Fixed `Deserializer` keeping the parsed tree after `Deserialize` returned, which made a second call on the same instance write through freed memory
- Fixed serialization to a failing stream aborting the process: the writers discarded the result of every stream write, and Beef traps on a discarded error. Both the DOM writer and the emitted serializers now propagate write failures as `StreamWriteFailed`, so a rejected or short write ends the document with an error instead of a trap or a silent truncation
- Fixed null reference fields crashing the emitted serializer: a null `String`, `List`, `Dictionary`, or nested `[JsonObject]` field now writes `null`, and `[JsonIgnore(Condition = .WhenWritingNull)]` skips it, which the condition previously did only for `Nullable<T>`
- Fixed a JSON null failing typed deserialization for reference and `Nullable<T>` fields: null now leaves the field at its current value instead of returning an error, so a document written by this library reads back
- Fixed unsupported collection element types emitting invalid JSON such as `[,,]` or `{"key":}` while reporting success. The generator now fails the build with the offending type name
- Fixed `[JsonPropertyName]` values being spliced into emitted code unescaped: a name holding a quote broke compilation, and a backslash corrupted the key and produced invalid JSON. Names are now escaped for both the emitted source and the JSON output, and a name holding a control character other than tab, newline, or carriage return fails generation
- Fixed `JsonPointer` rejecting array indexes above 2147483647 as malformed, and reduced the per token stack growth of pointer resolution to a single buffer
- Fixed the parser accepting invalid UTF-8: lone continuation bytes, overlong forms, truncated sequences, raw surrogate halves, and code points above U+10FFFF were copied into the document and re-emitted. They now fail with `InvalidEncoding`, as RFC 8259 section 8.1 requires
- Fixed `-9223372036854775808` overflowing at the negation, which aborted builds with arithmetic checks enabled, and fixed a bare `-0` losing its sign
- Fixed an unterminated block comment reporting a generic `UnableToRead` instead of naming the missing `closing */`, including from inside objects and arrays
- Fixed a lone carriage return not counting as a line break and a `\uXXXX` escape undercounting its column, so error positions are accurate
- Fixed an escape sequence cut short by end of input being accepted with a truncated code point
- Fixed `SchemaValidationResult.Errors` leaking on every failed validation, including the errors collected before an aborted validation
- Fixed a recursive `$ref` reporting `RefCycleDetected` once the instance nested two levels. A `$ref` that reaches itself without consuming instance is still reported
- Fixed a `$ref` naming an `$id` embedded in an already loaded schema being handed to the file resolver instead of resolving in memory
- Fixed `minLength` and `maxLength` counting UTF-8 bytes instead of Unicode code points
- Fixed `const`, `enum`, and `uniqueItems` comparing integers through `double`, which made values above 2^53 compare equal
- Fixed five ownership defects in `BJSON.SchemaCodeGen` that freed schema nodes twice or freed stack memory, and the CLI now reports a distinct non zero exit code for argument, schema, resolution, and output failures
- Fixed the generator omitting `[JsonPropertyName]` when a schema key differed from the field name only by case, which made every generated class look up keys that cannot match
- Fixed the generator copying `allOf` base properties into the derived class while also deriving from it, so generated types shadowed their base and serialized the inherited keys twice. `required` naming an inherited property now marks it on the base
- Fixed schema errors carrying a reference into freed memory: `RefNotFound`, `RefCycleDetected`, `ExternalSchemaNotFound`, and `ExternalSchemaParseError` viewed a buffer that reference resolution released, so printing the error read reclaimed memory. The reference now reads storage the `JsonSchema` owns until the next `Validate`

### API Changes

- `Json.Serialize(json, String)` and `Json.Serialize<T>(obj, String)` now append to the buffer instead of overwriting it from position zero, which used to leave stale trailing characters when the buffer was not empty
- `JsonWriter.WriteBool`, `WriteInt`, `WriteUInt`, `WriteString`, and `WriteEscaped` return `Result<void, JsonSerializationError>` instead of `void`, and `WriteRaw` and `WriteChar` are new. Regenerate types that carry an emitted serializer
- Added `JsonValue.AsString`, `AsBool`, and `AsNumber`, which report a type mismatch instead of the silent default the implicit conversions return
- Added `JsonSerializationError.StreamWriteFailed` and `JsonSerializationError.MaximumDepthReached`. Serializing a tree nested deeper than 200 levels now returns an error instead of overflowing the stack
- `JsonObject` and `JsonArray` no longer preallocate 32 dictionary slots and 16 list slots per container, which cut the cost of a small document by roughly an order of magnitude
- Trailing data now reports the real line number and names `end of document` as the expected token
- `JsonSchema.Validate` transfers ownership of the returned `SchemaValidationResult`, which now has a `Dispose`. Existing callers must dispose it
- The schema validator implements `multipleOf`, `contains`, `minContains`, `maxContains`, and `propertyNames`, which were silently ignored
- Removed the unreachable `JsonParsingError.DocumentIsEmpty` and `MissingQuotationMark` cases. An unescaped control character in a string now reports `UnexpectedToken` with `escaped control character`, and `InvalidEncoding` is reserved for UTF-8 validation
- `BJSON.SchemaCodeGen` names types from `title`, parses `definitions` and `$defs`, and rejects unsupported constructs by name instead of silently generating a type that does not represent the schema. Generated file names change accordingly

### Known Limitations

- `GetByPointerOrDefault<StringView>("")` still aliases a temporary. Use the non-generic overload to request the whole document

---

## v1.3.0

### New Features

**JsonRequired and JsonOptional Attributes**
- Added `[JsonRequired]` attribute to mark fields that must be present in JSON
- Added `[JsonOptional]` attribute to explicitly mark fields as optional
- Default behavior: all fields are optional (backward compatible)
- Supports primitives, classes, structs, and nested objects

**DefaultBehavior Configuration**
- New `JsonFieldDefaultBehavior` enum with `.Optional` and `.Required` values
- Configure at class level: `[JsonObject(DefaultBehavior = .Required)]`
- When DefaultBehavior is `.Required`, all fields are required by default
- Use `[JsonOptional]` to override Required default behavior

### API Changes

- Extended `[JsonObject]` attribute constructor to accept `DefaultBehavior` parameter
- Updated deserialization code generation to respect the new attributes and default behavior

---

## v1.2.0

### New Features

**Compile-Time Reflection Serialization**
- Added `Json.Serialize<T>()` and `Json.Deserialize<T>()` methods using comptime reflection
- Support for nested objects, collections, enums, and custom attributes
- New attributes: `[JsonConverter]`, `[JsonNumberHandling]`, `[JsonInclude]`

**Pretty-Print for Comptime Serializers**
- `IJsonSerializable` now supports `JsonWriterOptions` for indented output
- New `Json.Serialize<T>(T value, Stream stream, JsonWriterOptions options)` overloads

**Custom Converter Support**
- Added `IJsonConverter` interface for custom type serialization
- Use `[JsonConverter(typeof(MyConverter))]` attribute

**Inheritance Support**
- Serialization/deserialization now handles inherited fields
- Enum number handling via `[JsonNumberHandling]` attribute

**Small String Optimization (SSO)**
- Strings <=14 characters now use stack allocation, reducing heap pressure

**Improved Safe Access**
- Generic `GetOrDefault<T>()` overloads to avoid allocation for primitive defaults

### Bug Fixes
- Fixed memory leak in `Json.Deserialize<T>()`
- Fixed null termination in `dtoa` function
- Removed unused `GetTypeName()` method from JsonPointer

### Improvements
- Improved comment parsing error message: `"// or /* to start comment"`
- Removed excessive comments from source files
- New `TestRelease` build configuration with optimized flags
- Updated examples and documentation

---

## v1.1.0

Initial stable release with core JSON functionality.

---

## v1.0.0

Initial release.
