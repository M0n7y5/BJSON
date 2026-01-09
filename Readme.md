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
- Clone the repository or download the latest release from the [Releases](https://github.com/M0n7y5/BJSON/releases) page
- Add BJSON to your workspace via IDE

## Known Issues
> ### ⚠️ Be sure you have latest nightly of Beef IDE installed due to [some syntax not working](https://github.com/beefytech/Beef/issues/2366) properly in older versions. [This is now fixed in the compiler.](https://github.com/beefytech/Beef/commit/c592f205203d761ad6eb1861f7af5dd6f2d7cfe7)

## Usage

### Basic Deserialization

```cs
let jsonString = "{\"name\":\"BJSON\",\"version\":1.0}";
var result = Json.Deserialize(jsonString);
defer result.Dispose();

if (result case .Ok(let jsonValue))
{
    // we expect object
    if (let root = jsonValue.AsObject())
    {
        if (StringView name = root.GetValue("name"))
            Console.WriteLine(name);
    }
}
else if (result case .Err(let error))
{
    Console.WriteLine("Error: {}", error);
}
//Note: You can also use switch case statement as well
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
// JSONC (JSON with Comments)
var config = DeserializerConfig() { EnableComments = true };
var deserializer = scope Deserializer(config);

let jsonWithComments = """
{
    // Single-line comment
    "setting": "bing bong",
    /* Multi-line comment */
    "enabled": true
}
""";

var result = deserializer.Deserialize(jsonWithComments);
defer result.Dispose();

if (result case .Ok(let val))
{
    /* YOLO Errors
    StringView settings = val["setting"];
    Console.WriteLine(scope $"Settings value: {settings}");
    */

    // or safer way
    if (let root = val.AsObject())
    {
        if (StringView test = root.GetValue("setting"))
        {
            Console.WriteLine(test);
        }
    }
}
else if (result case .Err(let err))
{
    Console.WriteLine(err);
}
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

MIT License
