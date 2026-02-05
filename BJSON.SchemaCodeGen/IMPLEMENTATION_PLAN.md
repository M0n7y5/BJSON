# JSON Schema to Beef Code Generator - Implementation Plan

## Overview

A console tool that reads JSON Schema files and generates Beef classes with proper BJSON attributes for seamless JSON serialization/deserialization.

## Architecture

```
BJSON.SchemaCodeGen/
├── src/
│   ├── Main.bf                 # CLI entry point, argument parsing
│   ├── SchemaModel.bf          # Internal data models
│   ├── SchemaParser.bf         # JSON Schema to SchemaModel parsing
│   ├── TypeResolver.bf         # Type resolution, conflict detection
│   ├── CodeGenerator.bf        # Beef code generation
│   └── FileWriter.bf           # File output operations
└── BeefProj.toml
```

## Data Models

### SchemaModel
Internal representation of a JSON Schema:

```beef
class SchemaModel
{
    public String Name;              // Class/enum name (PascalCase)
    public String Description;       // For doc comments (from schema description)
    public SchemaType Type;          // Object, Array, String, Integer, Number, Boolean, Enum, Ref
    public bool IsNullable;          // For primitives: true if ["type", "null"]
    public Dictionary<String, PropertyModel> Properties;
    public List<String> Required;    // List of required property names
    public List<String> EnumValues;  // For enum types
    public SchemaModel Items;        // For arrays: schema of items
    public List<SchemaModel> AllOf;  // For inheritance (base classes)
    public SchemaModel ReferencedSchema; // For $ref: resolved schema
    public String RefPath;           // Original $ref path (for tracking)
}
```

### PropertyModel
Represents a property/field:

```beef
class PropertyModel
{
    public String Name;              // Property name (PascalCase for Beef field)
    public String JsonName;          // Original JSON name (for JsonPropertyName attribute)
    public SchemaModel Schema;       // Type schema
    public bool IsRequired;          // True if in schema's required array
    public String DefaultValue;      // Default value if specified
    public String Description;       // For doc comments
}
```

### SchemaType Enum

```beef
enum SchemaType
{
    Object,
    Array,
    String,
    Integer,
    Number,
    Boolean,
    Enum,
    Ref,         // Reference to another schema
    Any          // Untyped/any type
}
```

## Type Mapping

| JSON Schema | Beef Type | Initialization |
|-------------|-----------|----------------|
| `"type": "string"` | `String` | `= new .() ~ delete _` |
| `"type": "integer"` | `int64` | None (configurable: int32) |
| `"type": "number"` | `double` | None (configurable: float) |
| `"type": "boolean"` | `bool` | None |
| `"type": "array"` | `List<T>` | `= new .() ~ DeleteContainerAndItems!(_)` |
| `"type": "object"` | Custom class | `= new .() ~ delete _` |
| `["string", "null"]` | `String` | `= new .() ~ delete _` (implicit nullable) |
| `["integer", "null"]` | `int64?` | None (explicit nullable) |
| `["number", "null"]` | `double?` | None (explicit nullable) |
| `["boolean", "null"]` | `bool?` | None (explicit nullable) |
| `enum: [...]` | Beef enum | None (value type) |
| `$ref` | Referenced class | `= new .() ~ delete _` |

## Naming Conventions

### Root Class
- Use schema `title` field if present
- Otherwise derive from filename: `user.schema.json` → `User`
- Convert to PascalCase

### Nested Classes
- Use property name in PascalCase
- Property `billingAddress` → class `BillingAddress`
- Property `items` → class `Items` (keep plural)

### Conflict Resolution
- Track all generated class names in a set
- If name collision detected:
  - Option 1: Append number suffix: `Address`, `Address2`
  - Option 2: Use parent prefix: `UserAddress`, `CompanyAddress`
- **Decision**: Use Option 1 (simpler, consistent)

### Property Names
- Convert JSON property names to PascalCase for Beef fields
- Store original name in `JsonName` for `[JsonPropertyName]` attribute
- Example: `user_name` → field `UserName` with `[JsonPropertyName("user_name")]`

## Code Generation Rules

### File Structure
- One file per class/enum
- Flat directory structure (all files in output directory)
- File naming: `{ClassName}.bf` (PascalCase)

### File Template

```beef
using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace {Namespace};

{Documentation}
[JsonObject]
class {ClassName}{Inheritance}
{
    {Fields}
}
```

### Field Generation

**Required field (in schema's `required` array):**
```beef
[JsonRequired]
public String Name = new .() ~ delete _;
```

**Optional field:**
```beef
public String Email = new .() ~ delete _;
```

**Field with custom JSON name:**
```beef
[JsonPropertyName("user_name")]
public String UserName = new .() ~ delete _;
```

**Nullable primitive:**
```beef
public int64? Age;
```

**List field:**
```beef
public List<Order> Orders = new .() ~ DeleteContainerAndItems!(_);
```

**Nested class field:**
```beef
public Address BillingAddress = new .() ~ delete _;
```

**Enum field:**
```beef
public StatusType Status;
```

### Enum Generation

```beef
using BJSON.Attributes;

namespace {Namespace};

[JsonObject]
enum {EnumName}
{
    {Value1},
    {Value2},
    {Value3}
}
```

### Inheritance (allOf)

When schema uses `allOf` with $ref:
```json
{
  "allOf": [
    { "$ref": "#/definitions/Person" },
    {
      "type": "object",
      "properties": {
        "employeeId": { "type": "integer" }
      }
    }
  ]
}
```

Generate:
```beef
[JsonObject]
class Employee : Person
{
    public int64 EmployeeId;
}
```

**Notes:**
- First $ref in allOf becomes base class
- Additional properties merged into derived class
- Multiple allOf schemas: only support single inheritance (first $ref is base)

### Documentation Comments

Generate `///` comments from schema `description`:

```beef
/// Represents a user in the system
[JsonObject]
class User
{
    /// The user's unique identifier
    [JsonRequired]
    public int64 Id;
}
```

## CLI Interface

### Usage

```bash
BJSON.SchemaCodeGen [options] <schema.json>
```

### Arguments

| Argument | Description |
|----------|-------------|
| `schema.json` | Input JSON Schema file (required) |

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

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Schema parse error |
| 3 | Type resolution error |
| 4 | File write error |

## Implementation Details

### Phase 1: Foundation

**SchemaModel.bf**
- Define `SchemaModel`, `PropertyModel`, `SchemaType`
- Simple data containers

**SchemaParser.bf**
- Parse JSON Schema (using existing BJSON library)
- Convert to SchemaModel
- Handle:
  - Primitive types
  - Objects and properties
  - Arrays
  - Enums
  - $ref (store path for later resolution)
  - allOf (store list for later processing)
  - required array
  - description

### Phase 2: Type Resolution

**TypeResolver.bf**
- Build dependency graph
- Resolve $ref references (local only)
- Detect naming conflicts
- Assign final class names
- Handle inheritance (allOf)

**Key algorithm:**
1. Collect all schemas (root + nested)
2. Assign initial names (based on rules)
3. Detect conflicts
4. Resolve conflicts (append numbers)
5. Resolve $refs (link to actual schemas)
6. Process allOf (determine inheritance)

### Phase 3: Code Generation

**CodeGenerator.bf**
- Generate code for each schema
- Use StringBuilder pattern
- Generate:
  - File header (usings, namespace)
  - Class declaration (with inheritance)
  - Doc comments
  - Fields with proper types and attributes
  - Initializers for reference types

**Generation order:**
1. Enums first
2. Base classes (from allOf)
3. Derived classes
4. Root class last

### Phase 4: File Writing

**FileWriter.bf**
- Create output directory if needed
- Write one file per class/enum
- UTF-8 encoding
- Handle file system errors

### Phase 5: CLI

**Main.bf**
- Parse command-line arguments
- Validate inputs
- Call parser → resolver → generator → writer
- Handle errors and return appropriate exit codes

## Features NOT Supported

These JSON Schema features are intentionally not supported for MVP:

1. **External $ref** ($ref to HTTP URLs)
   - Only local file refs and internal #refs
   - Reason: Requires HTTP client, complex resolution

2. **oneOf / anyOf**
   - Reason: Complex union type generation
   - Alternative: Use inheritance or flatten

3. **patternProperties**
   - Reason: Requires regex, dynamic property handling
   - Alternative: Use additionalProperties

4. **if/then/else**
   - Reason: Complex conditional logic
   - Alternative: Use inheritance or allOf

5. **$dynamicRef / $dynamicAnchor**
   - Reason: Advanced feature, rare use case

6. **Format validation**
   - Reason: BJSON doesn't support format keyword
   - Workaround: Use string type, validate in app code

7. **additionalProperties: {schema}**
   - Ignored (we only support true/false/undefined)
   - Reason: Requires dynamic dictionary handling

8. **propertyNames**
   - Reason: Rare use case

9. **contains, minContains, maxContains**
   - Reason: Complex array validation

10. **dependencies / dependentSchemas / dependentRequired**
    - Reason: Complex dependency logic

## Error Handling

### Schema Parse Errors
- Invalid JSON syntax
- Unsupported type values
- Malformed $ref paths
- **Action**: Print error message, exit code 2

### Type Resolution Errors
- Circular $ref (A refs B, B refs A)
- Unresolved $ref (path not found)
- Naming conflicts (can't resolve)
- **Action**: Print error message with path, exit code 3

### File Write Errors
- Cannot create directory
- Permission denied
- Disk full
- **Action**: Print error message, exit code 4

## Testing Strategy

### Test Cases

1. **Primitive types**
   - String, integer, number, boolean
   - Nullable variants

2. **Complex objects**
   - Nested objects
   - Multiple levels

3. **Arrays**
   - Arrays of primitives
   - Arrays of objects
   - Nested arrays

4. **Enums**
   - String enums
   - Various naming styles

5. **Required fields**
   - Mix of required and optional
   - All required
   - All optional

6. **References**
   - Local $ref
   - Nested $ref
   - $ref cycles (should error)

7. **Inheritance**
   - allOf with $ref
   - Deep inheritance chains

8. **Naming conflicts**
   - Same name in different branches
   - Case sensitivity

9. **Edge cases**
   - Empty objects
   - Empty arrays
   - Very deep nesting

### Example Test Schemas

Create in `BJSON.SchemaCodeGen.Tests/`:
- `primitives.schema.json`
- `nested-objects.schema.json`
- `arrays.schema.json`
- `enums.schema.json`
- `required-fields.schema.json`
- `inheritance.schema.json`
- `conflicts.schema.json`

## Memory Management

### Generated Classes
- Use `~ delete _` for String fields
- Use `~ DeleteContainerAndItems!(_)` for List fields
- No explicit destructors generated
- Rely on Beef's implicit destructor calling field destructors

### Tool Itself
- Use `scope` for temporary allocations
- Use `delete` for long-lived objects
- Proper cleanup in error paths

## Code Style

Follow BJSON project conventions:
- Tabs for indentation
- PascalCase for types and methods
- camelCase for private fields
- Opening brace on same line
- Minimal comments (code should be self-documenting)

## Future Enhancements

Post-MVP features to consider:

1. **oneOf/anyOf support**
   - Generate discriminated unions using Beef enums with associated data

2. **External $ref**
   - HTTP/HTTPS resolution
   - Local file references

3. **Validation generation**
   - Generate validation methods for constraints not handled by BJSON

4. **Multiple files input**
   - Process multiple schemas in one run
   - Shared type resolution across files

5. **Configuration file**
   - `.bjsongen` config file for project-wide settings

6. **Watch mode**
   - Auto-regenerate on schema file changes

## Implementation Checklist

- [ ] SchemaModel.bf - Data structures
- [ ] SchemaParser.bf - Parsing logic
- [ ] TypeResolver.bf - Resolution and conflict handling
- [ ] CodeGenerator.bf - Code generation
- [ ] FileWriter.bf - File output
- [ ] Main.bf - CLI interface
- [ ] Error handling throughout
- [ ] Test with various schemas
- [ ] Documentation

## Dependencies

- BJSON library (for parsing JSON Schema)
- Beef standard library
- No external dependencies
