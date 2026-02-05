# Changelog

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
