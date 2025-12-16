# BJSON

A high-performance JSON parser and serializer for the Beef programming language.

## Features

- RFC 8259 compliant
- Result-based error handling
- Pretty-print support
- Stream-based parsing
- Comment support (optional)
- Optimized performance

## Installation

Add BJSON to your workspace in `BeefSpace.toml`:

```toml
[Workspace]
Projects = ["BJSON", "YourProject"]
```

Or add as a dependency in `BeefProj.toml`:

```toml
[Dependencies]
BJSON = "*"
```

## Usage

### Basic Deserialization

```cs
using BJSON;
using System;

let jsonString = "{\"name\":\"BJSON\",\"version\":1.0}";
var result = Json.Deserialize(jsonString);
defer result.Dispose();

if (result case .Ok(let jsonValue))
{
    if (let obj = jsonValue as JsonObject)
    {
        if (let name = obj.Get("name") as JsonString)
            Console.WriteLine(name.Value);
    }
}
else if (result case .Err(let error))
{
    Console.WriteLine("Error: {}", error);
}
```

### Basic Serialization
```cs
let json = JsonObject()
{
    ("firstName", "John"),
    ("lastName", "Smith"),
    ("isAlive", true),
    ("age", 27)
};
defer json.Dispose();

let output = scope String();
Json.Serialize(json, output);
Console.WriteLine(output);
```

### Pretty-Print

```cs
let json = JsonObject()
    {
        ("firstName", "John"),
        ("lastName", "Smith"),
        ("isAlive", true),
        ("age", 27),
        ("phoneNumbers", JsonArray()
            {
                JsonObject()
                    {
                        ("type", "home"),
                        ("number", "212 555-1234")
                    },

                JsonObject()
                    {
                        ("type", "office"),
                        ("number", "646 555-4567")
                    }
            })
    };
defer json.Dispose();
let output = scope String();
let options = JsonWriterOptions() { Indented = true };
Json.Serialize(json, output, options);
Console.WriteLine(output);
```

### Comment Support

Enable JSONC (JSON with Comments) parsing:

```cs
var config = DeserializerConfig() { EnableComments = true };
var deserializer = scope Deserializer(config);

let jsonWithComments = """
{
  // Single-line comment
  "setting": "value",
  /* Multi-line comment */
  "enabled": true
}
""";

var result = deserializer.Deserialize(jsonWithComments);
defer result.Dispose();
```

## API Reference

### Main Classes

- `Json` - Static methods for serialization and deserialization
- `Deserializer` - Configurable JSON parser
- `JsonWriter` - Output serialization
- `JsonReader` - Stream-based input parsing

### JsonValue Types

- `JsonNull`
- `JsonBool`
- `JsonNumber`
- `JsonString`
- `JsonArray`
- `JsonObject`

### Configuration

**DeserializerConfig**
- `EnableComments` - Allow C-style comments (default: false)

**JsonWriterOptions**
- `Indented` - Enable pretty-printing (default: false)
- `IndentString` - Indentation string (default: "  ")

## Testing

The library includes comprehensive test suites covering RFC compliance, edge cases, and error handling.

### Running Tests

```bash
BeefBuild.exe -test
```

Or build the test project via IDE.

Test suites include:
- JSON.org standard tests
- Native JSON benchmark roundtrips
- NST JSON test suite
- Big List of Naughty Strings

## License

Open source. See repository for details.
