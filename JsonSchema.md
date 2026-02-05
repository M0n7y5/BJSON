# JSON Schema Support

BJSON includes JSON Schema 2020-12 validation support for validating JSON data against defined schemas.

## Overview

JSON Schema allows you to define the structure, content, and validation rules for your JSON data. BJSON's implementation supports the core validation keywords and reference resolution mechanisms.

## Supported Features

### Type Validation

Validate JSON values against specific types:

```json
{
    "type": "object",
    "properties": {
        "name": { "type": "string" },
        "age": { "type": "integer" },
        "price": { "type": "number" },
        "active": { "type": "boolean" },
        "data": { "type": "array" },
        "config": { "type": "object" },
        "empty": { "type": "null" }
    }
}
```

**Supported types:** `null`, `boolean`, `number`, `integer`, `string`, `object`, `array`

### Object Validation

Control object structure and required fields:

```json
{
    "type": "object",
    "properties": {
        "name": { "type": "string" },
        "email": { "type": "string" }
    },
    "required": ["name"],
    "minProperties": 1,
    "maxProperties": 5,
    "additionalProperties": false
}
```

**Keywords:** `properties`, `required`, `minProperties`, `maxProperties`, `additionalProperties`

### Array Validation

Validate arrays and their contents:

```json
{
    "type": "array",
    "items": { "type": "string" },
    "minItems": 1,
    "maxItems": 10,
    "uniqueItems": true
}
```

**Keywords:** `items`, `prefixItems`, `additionalItems`, `minItems`, `maxItems`, `uniqueItems`

### Numeric Validation

Set constraints on numeric values:

```json
{
    "type": "number",
    "minimum": 0,
    "maximum": 100,
    "exclusiveMinimum": 0,
    "exclusiveMaximum": 100
}
```

**Keywords:** `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`

### String Validation

Set length constraints on strings:

```json
{
    "type": "string",
    "minLength": 1,
    "maxLength": 255
}
```

**Keywords:** `minLength`, `maxLength`

### Combining Schemas

Create complex validation logic:

```json
{
    "allOf": [
        { "type": "object" },
        { "required": ["id"] }
    ],
    "anyOf": [
        { "required": ["name"] },
        { "required": ["title"] }
    ],
    "oneOf": [
        { "properties": { "type": { "const": "user" } } },
        { "properties": { "type": { "const": "admin" } } }
    ]
}
```

**Keywords:** `allOf`, `anyOf`, `oneOf`, `not`

### Conditional Validation

Apply schemas conditionally:

```json
{
    "type": "object",
    "properties": {
        "role": { "type": "string" }
    },
    "if": {
        "properties": { "role": { "const": "admin" } }
    },
    "then": {
        "required": ["permissions"]
    },
    "else": {
        "required": ["department"]
    }
}
```

**Keywords:** `if`, `then`, `else`

### Constants and Enums

Restrict to specific values:

```json
{
    "enum": ["red", "green", "blue"],
    "const": "active"
}
```

**Keywords:** `enum`, `const`

### References

Reference and reuse schema definitions:

```json
{
    "$defs": {
        "address": {
            "type": "object",
            "properties": {
                "street": { "type": "string" },
                "city": { "type": "string" }
            }
        }
    },
    "type": "object",
    "properties": {
        "homeAddress": { "$ref": "#/$defs/address" },
        "workAddress": { "$ref": "#/$defs/address" }
    }
}
```

**Keywords:** `$ref`, `$id`, `$anchor`, `$defs`, `definitions`

**Reference types supported:**
- Local references: `#/$defs/schemaName`
- External file references: `file:///path/to/schema.json` or `C:\path\to\schema.json`

### Boolean Schemas

Shorthand for always valid or invalid schemas:

```json
{
    "properties": {
        "data": true,    // Always valid
        "blocked": false // Always invalid
    }
}
```

## Not Supported

### `pattern` (Regex)

**Why:** Requires a regex library dependency. Beef's standard library doesn't include a full regex implementation.

**Workaround:** Validate string patterns in application code after schema validation.

### `format` (Date, Email, URI, etc.)

**Why:** Format validation is complex and requires specific parsing logic for each format type. Would add significant complexity.

**Workaround:** Use `type: "string"` and validate formats in application code.

### `patternProperties`

**Why:** Depends on regex support for pattern matching.

**Workaround:** Use `properties` with explicit property names or validate patterns in application code.

### `dependentSchemas` / `dependentRequired`

**Why:** These are less commonly used keywords that add complexity to the implementation.

**Workaround:** Use `if/then/else` for conditional validation.

### `unevaluatedProperties` / `unevaluatedItems`

**Why:** Requires tracking which properties/items were evaluated during validation, significantly complicating the validation engine.

**Workaround:** Use `additionalProperties: false` or carefully structure your schemas.

### `$dynamicRef` / `$dynamicAnchor`

**Why:** These are advanced features for dynamic schema composition that require complex resolution logic.

**Workaround:** Use standard `$ref` with `$id` for static schema composition.

### HTTP/HTTPS Schema Resolution

**Why:** Would require HTTP client implementation and network dependencies.

**Workaround:** Use local file references and load external schemas manually.

## Usage Examples

### Basic Validation

```beef
using BJSON;
using BJSON.Models;

// Define a schema
let schemaJson = """
    {
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "integer", "minimum": 0 }
        },
        "required": ["name"]
    }
    """;

// Parse the schema
let schemaResult = JsonSchema.Parse(schemaJson);
if (schemaResult case .Err(let err))
{
    Console.WriteLine("Failed to parse schema");
    return;
}

// Validate JSON
let json = Json.Deserialize("{\"name\":\"Alice\",\"age\":30}");
if (json case .Ok(let value))
{
    let result = schemaResult.Value.Validate(value);
    if (result case .Ok(let validation))
    {
        Console.WriteLine(scope $"Valid: {validation.IsValid}");
        
        // Check errors if invalid
        if (!validation.IsValid && validation.Errors != null)
        {
            for (let error in validation.Errors)
            {
                Console.WriteLine(scope $"Error: {error.Message} at {error.InstancePointer}");
            }
        }
    }
}

// Clean up
delete schemaResult.Value;
```

### Using References

```beef
// Schema with local $ref
let schemaWithRef = """
    {
        "$defs": {
            "person": {
                "type": "object",
                "properties": {
                    "name": { "type": "string" },
                    "age": { "type": "integer" }
                }
            }
        },
        "$ref": "#/$defs/person"
    }
    """;

let schema = JsonSchema.Parse(schemaWithRef);
if (schema case .Ok(let s))
{
    // The schema validates against the $ref target
    let result = s.Validate(JsonValue.Parse("{\"name\":\"Bob\"}"));
    delete s;
}
```

### External Schema Reference

```beef
// Create a schema that references an external file
var schemaRoot = JsonObject();
schemaRoot.Add("$ref", JsonString("C:\\schemas\\person.json"));

let schemaResult = JsonSchema.FromRoot(schemaRoot);
if (schemaResult case .Ok(let schema))
{
    let instance = Json.Deserialize("{\"name\":\"Eve\",\"age\":42}");
    let result = schema.Validate(instance.Value);
    // ...
    delete schema;
}
```

### Validation Options

```beef
// Limit the number of errors collected
let options = SchemaValidationOptions() { MaxErrors = 5 };
let result = schema.Validate(jsonValue, options);
```

## Memory Management

JSON Schema uses classes (reference types) in Beef. When you're done with a schema, use `delete` to free the memory:

```beef
let schemaResult = JsonSchema.Parse(schemaJson);
if (schemaResult case .Ok)
{
    // Use the schema...
    
    // Clean up when done
    delete schemaResult.Value;
}
```

The destructor (`~this()`) automatically handles cleaning up:
- The root schema document
- Any referenced external documents
- Internal indexes and caches
- The resolver (if owned by the schema)

## Error Handling

The validation result includes detailed error information:

```beef
if (validation.Errors != null)
{
    for (let error in validation.Errors)
    {
        Console.WriteLine(scope $"Message: {error.Message}");
        Console.WriteLine(scope $"Instance location: {error.InstancePointer}");
        Console.WriteLine(scope $"Schema location: {error.SchemaPointer}");
    }
}
```

## Limitations

- Maximum validation depth: 200 nested levels (prevents stack overflow on circular references)
- Maximum error collection: Configurable via `SchemaValidationOptions.MaxErrors` (default: 16)
- No regex support: Pattern validation must be done in application code
- File-based external references only: No HTTP/HTTPS URL support

## See Also

- [JSON Schema 2020-12 Specification](https://json-schema.org/draft/2020-12/schema)
- [JSON Schema Documentation](https://json-schema.org/)
- `BJSON.Example/src/Program.bf` - Contains a working JSON Schema example
