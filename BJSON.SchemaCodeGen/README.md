# BJSON.SchemaCodeGen

JSON Schema to Beef Code Generator

## Overview

A console tool that reads JSON Schema files and generates Beef classes with proper BJSON attributes for seamless JSON serialization/deserialization.

## Usage

```bash
BJSON.SchemaCodeGen [options] <schema.json>
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--output` | `-o` | Output directory | `./generated` |
| `--namespace` | `-n` | Namespace for classes | Required |
| `--class` | `-c` | Root class name override | Schema title or filename |
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
| `"type": "array"` | `List<T>` | `= new .() ~ DeleteContainerAndItems!(_)` |
| `"type": "object"` | Custom class | `= new .() ~ delete _` |
| `enum: [...]` | Beef enum | None (value type) |
| `$ref` | Referenced class | `= new .() ~ delete _` |

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
- Generate Beef classes with `[JsonObject]` attribute
- Generate `[JsonRequired]` for required fields
- Generate `[JsonPropertyName]` for custom JSON property names
- Handle nullable types with `?` suffix
- Resolve naming conflicts (Appends numbers: Address, Address2)
- Support for inheritance via `allOf`
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

## Building

Note: You'll need to create the `BeefProj.toml` file manually to integrate this into your Beef workspace. The source files are ready - just add the project configuration.

## Limitations

Not supported in MVP:
- External $ref (HTTP URLs)
- oneOf / anyOf (complex unions)
- patternProperties
- if/then/else
- $dynamicRef / $dynamicAnchor
- Format validation
- additionalProperties with schemas
- propertyNames
- contains, minContains, maxContains
- dependencies / dependentSchemas
