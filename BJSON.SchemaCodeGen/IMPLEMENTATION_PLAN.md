# JSON Schema to Beef Code Generator - v1 Notes

## Scope

`BJSON.SchemaCodeGen` is a structural model generator for common JSON Schema documents. It generates Beef classes and enums with BJSON serialization metadata only. It does not generate runtime constraint validation; use `BJSON.JsonSchema` for validation.

Supported v1 structures:
- Objects and nested objects
- Arrays of primitives and objects
- String enums
- Nullable primitive schemas such as `["integer", "null"]`
- Required fields via `[JsonRequired]`
- `definitions` and `$defs`
- Internal refs: `#`, `#/definitions/...`, and `#/$defs/...`
- `allOf` object composition by field flattening

## CLI Behavior

Usage remains:

```bash
BJSON.SchemaCodeGen [options] <schema.json>
```

Use `--warnings-as-errors` for strict CI runs that should reject schemas which emit parser or resolver warnings. Warnings are still printed before the tool exits.

Root class naming order:
1. `--class`
2. Schema `title`
3. Input filename

Exit codes:
- `0`: successful generation, including successful generation with warnings
- `1`: invalid arguments
- `2`: invalid JSON or schema parse failure
- `3`: type resolution failure, such as unresolved internal refs or circular refs
- `4`: file write failure
- `5`: warnings were emitted with `--warnings-as-errors`; no files are written for that run

## Generation Rules

The generator emits one `.bf` file per generated object or enum. Classes include `[JsonObject]`; required properties include `[JsonRequired]`; JSON property names that do not match the Beef field name include `[JsonPropertyName]`.

Type mapping:
- `string` -> `String`
- `integer` -> `int64` by default, configurable to `int32`
- `number` -> `double` by default, configurable to `float`
- `boolean` -> `bool`
- `array` -> `List<T>`
- `object` -> generated class
- string `enum` -> Beef enum
- unsupported structural fallback -> `JsonValue`

Array memory management depends on item type. Lists of value types use `~ delete _`; lists of `String`, generated objects, refs to generated objects, or nested lists use `~ DeleteContainerAndItems!(_)`.

## Refs

Internal refs are indexed by JSON pointer. Supported forms are:
- `#`
- `#/$defs/Name`
- `#/definitions/Name`

External and file refs are intentionally deferred. They produce warnings and fall back to `JsonValue`, allowing generation to continue.

Unresolved internal refs are hard errors because they indicate an inconsistent input document.

## allOf

`allOf` no longer generates Beef inheritance. Object members are flattened into the containing class:
- Object subschema properties are copied into the target class.
- `[JsonRequired]` is preserved from both subschema `required` lists and the target schema `required` list.
- Duplicate fields keep the first existing field and emit a warning.
- Inline `allOf` object wrappers are not emitted as standalone base classes.

## Warnings

Unsupported validation keywords and unsupported schema constructs emit warnings but do not fail generation when a useful structural model can still be produced.

Ignored validation-only examples:
- `minimum`, `maximum`, `multipleOf`
- `minLength`, `maxLength`, `format`, `pattern`
- `minItems`, `maxItems`, `uniqueItems`
- `additionalProperties`, `patternProperties`, `propertyNames`

Unsupported constructs that warn and are ignored structurally include `anyOf`, `oneOf`, `not`, `if`, `then`, `else`, `$dynamicRef`, and `$dynamicAnchor`.

When `--warnings-as-errors` is enabled, parser and resolver warnings are printed after successful type resolution, then generation exits with code `5` before creating the output directory or writing files. Type resolution errors keep higher priority and return code `3`.

## Verification

Acceptance commands:

```bash
/home/admin/repos/Beef/IDE/dist/BeefBuild -workspace=. -project=BJSON.SchemaCodeGen -config=Debug
/home/admin/repos/Beef/IDE/dist/BeefBuild -workspace=. -project=BJSON.SchemaCodeGenTest -config=Test
/home/admin/repos/Beef/IDE/dist/BeefBuild -workspace=. -test -config=Test
```

`BJSON.SchemaCodeGenTest/src` contains generated compile-gate baselines. `BJSON.SchemaCodeGen.Tests` covers parsing, ref resolution, `allOf` flattening, warning fallback, and unresolved-ref failure.
