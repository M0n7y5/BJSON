# Changelog

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

### API Changes

- `Json.Serialize(json, String)` and `Json.Serialize<T>(obj, String)` now append to the buffer instead of overwriting it from position zero, which used to leave stale trailing characters when the buffer was not empty
- `JsonWriter.WriteBool`, `WriteInt`, `WriteUInt`, `WriteString`, and `WriteEscaped` return `Result<void, JsonSerializationError>` instead of `void`, and `WriteRaw` and `WriteChar` are new. Regenerate types that carry an emitted serializer
- Added `JsonSerializationError.StreamWriteFailed`
- Trailing data now reports the real line number and names `end of document` as the expected token

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
