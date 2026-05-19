# BJSON.SchemaCodeGen

JSON Schema to Beef Code Generator

## Overview

A console tool that reads JSON Schema files and generates structural Beef models with BJSON serialization attributes. Runtime validation remains the responsibility of `BJSON.JsonSchema`; generated classes do not include validation methods.

## Usage

```bash
BJSON.SchemaCodeGen [options] <schema.json>
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--output` | `-o` | Output directory | `./generated` |
| `--namespace` | `-n` | Namespace for classes | Required |
| `--class` | `-c` | Root class name override | Schema `title` or filename |
| `--integer-type` | | Integer type: int32, int64 | `int64` |
| `--number-type` | | Number type: float, double | `double` |
| `--skip-docs` | | Skip documentation comments | `false` |
| `--help` | `-h` | Show help | |

### Examples

```bash
# Basic usage
BJSON.SchemaCodeGen user.schema.json -n MyApp.Models

# Specify output directory
BJSON.SchemaCodeGen api.schema.json -o ./src/Models -n Api.Models

# Override root class name
BJSON.SchemaCodeGen schema.json -n MyApp -c ApiResponse

# Use 32-bit integers
BJSON.SchemaCodeGen data.json -n Models --integer-type int32
```

## Type Mapping

| JSON Schema | Beef Type | Initialization |
|-------------|-----------|----------------|
| `"type": "string"` | `String` | `= new .() ~ delete _` |
| `"type": "integer"` | `int64` | None (or `int32?` if nullable) |
| `"type": "number"` | `double` | None (or `double?` if nullable) |
| `"type": "boolean"` | `bool` | None (or `bool?` if nullable) |
| `"type": "array"` | `List<T>` | `= new .() ~ delete _` for value items, `DeleteContainerAndItems!(_)` for reference items |
| `"type": "object"` | Custom class | `= new .() ~ delete _` |
| `enum: [...]` | Beef enum | None (value type) |
| Internal `$ref` | Referenced class/enum | Based on referenced type |

## Architecture

```
BJSON.SchemaCodeGen/
├── src/
│   ├── Main.bf           # CLI entry point
│   ├── SchemaModel.bf    # Data models
│   ├── SchemaParser.bf   # JSON Schema parsing
│   ├── TypeResolver.bf   # Type resolution & conflict handling
│   ├── CodeGenerator.bf  # Beef code generation
│   └── FileWriter.bf     # File output
└── tests/
    ├── primitives.schema.json
    ├── nested-objects.schema.json
    ├── enums.schema.json
    └── references.schema.json
```

## Features

- Parse JSON Schema files (primitive types, objects, arrays, enums)
- Use root class naming order: `--class`, schema `title`, then input filename
- Generate Beef classes with `[JsonObject]` attribute
- Generate `[JsonRequired]` for required fields
- Generate `[JsonPropertyName]` for custom JSON property names
- Handle nullable types with `?` suffix
- Resolve internal refs: `#`, `#/definitions/...`, and `#/$defs/...`
- Parse `definitions` and `$defs`
- Flatten object fields from `allOf` into the generated class
- Emit warnings for unsupported validation keywords while still generating useful structural models
- Resolve naming conflicts (Appends numbers: Address, Address2)
- Documentation comments from schema `description`

## Memory Management

Generated classes use proper Beef destructors:
- `String` fields: `~ delete _`
- `List` fields: `~ DeleteContainerAndItems!(_)`
- Reference type fields: `~ delete _`

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Schema parse error |
| 3 | Type resolution error |
| 4 | File write error |

Warnings do not change the exit code. Invalid JSON, invalid arguments, unresolved internal refs, circular refs, and file-write failures return nonzero codes.

## Building

From the workspace root:

```bash
/home/admin/repos/Beef/IDE/dist/BeefBuild -workspace=. -project=BJSON.SchemaCodeGen -config=Debug
```

## Limitations

Not supported in v1:
- External/file `$ref` resolution. These produce warnings and fall back to `JsonValue`.
- Generated validation methods. Use `BJSON.JsonSchema` for runtime validation.
- oneOf / anyOf (complex unions)
- patternProperties
- if/then/else
- $dynamicRef / $dynamicAnchor
- Validation-only keywords such as `minimum`, `maxLength`, `format`, `pattern`, `minItems`, and `additionalProperties`
- additionalProperties with schemas
- propertyNames
- contains, minContains, maxContains
- dependencies / dependentSchemas
