![](bjson_logo_128.png)

# BJSON

A high-performance JSON serializer and deserializer for the Beef programming language.

## Features

- RFC 8259 compliant
- RFC 6901 JSON Pointer support
- **Attribute-based serialization** with `[JsonObject]` using compile time reflection and code generation
- Result-based error handling
- Pretty-print support
- Stream-based parsing and serialization
- Comment support (optional JSONC)
- Safe access methods (TryGet, GetOrDefault)

## Installation
- Clone the repository or download the latest release from the [Releases](https://github.com/M0n7y5/BJSON/releases) page
- Add BJSON to your workspace via IDE

## Known Issues
> ### ⚠️ Be sure you have latest nightly of Beef IDE installed due to [some syntax not working](https://github.com/beefytech/Beef/issues/2366) properly in older versions. [This is now fixed in the compiler.](https://github.com/beefytech/Beef/commit/c592f205203d761ad6eb1861f7af5dd6f2d7cfe7)

## Performance

BJSON is designed for high-performance JSON processing with several key optimizations:

- **Small String Optimization (SSO)** — String values ≤14 characters are stored inline within the JsonValue struct, requiring zero heap allocation
- **BumpAllocator Integration** — Object keys are allocated using efficient bump allocation during parsing
- **Fast Number Conversion**: doubles convert through the Beef runtime's Zmij implementation (shortest round-trip form, about 1.8x faster than the Grisu2 port it replaces)
- **Configurable Duplicate Key Handling** — Choose between throwing errors, ignoring duplicates, or always rewriting (default)

## Usage

### Attribute-based Serialization (Recommended)

The easiest way to work with JSON is using the `[JsonObject]` attribute for automatic serialization:

```cs
using BJSON;
using BJSON.Attributes;
using System.Collections;

[JsonObject]
class Person
{
    public String Name = new .() ~ delete _;
    public int Age;
    public bool IsActive;
    
    [JsonPropertyName("email_address")]  // Custom JSON property name
    public String Email = new .() ~ delete _;
    
    public List<String> Tags = new .() ~ DeleteContainerAndItems!(_);
    
    [JsonIgnore(Condition = .Always)]  // Exclude from serialization
    public int InternalId;
}

// Serialize to JSON
let person = scope Person();
person.Name.Set("John Doe");
person.Age = 30;

let output = scope String();
if (Json.Serialize(person, output) case .Err)
    return; // a failed or short write ends the document with an error
// Output: {"Name":"John Doe","Age":30,"IsActive":false,"email_address":"","Tags":[]}

// Deserialize from JSON (pre-allocated object)
let json = """{"Name":"Jane","Age":25}""";
let restored = scope Person();
if (Json.Deserialize<Person>(json, restored) case .Err(let err))
{
    // err names the failure, e.g. "Type mismatch at /Age: expected number, got string"
}

// Or use allocating API (caller must delete)
if (Json.Deserialize<Person>(json) case .Ok(let newPerson))
{
    defer delete newPerson;
    // use newPerson...
}
```

#### Supported Field Types
- Primitives: `bool`, `int`, `float`, `double`, etc.
- `String` (must be pre-allocated with `new .() ~ delete _`)
- Enums (serialized as strings)
- Nullable types (`int?`, `float?`) - treated as optional
- `List<T>` for any supported type
- `Dictionary<String, T>` (string keys only)
- Sized arrays (`int[3]`, `float[N]`)
- Nested objects with `[JsonObject]`

#### Attributes
- `[JsonObject]` - Mark class/struct for serialization
- `[JsonPropertyName("name")]` - Custom JSON property name
- `[JsonIgnore]` - Exclude field from serialization
- `[JsonInclude]` - Include private fields
- `[JsonExtensionData]` - Capture unknown object properties in one `Dictionary<String, T>` field

### JsonValue API

For dynamic JSON handling without predefined types:

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
if (Json.Serialize(json, output) case .Err)
    return;
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
if (Json.Serialize(json, output, options) case .Err)
    return;
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

### Safe Access Methods

Use `TryGet` and `GetOrDefault` to safely access values without crashes:

```cs
let json = JsonObject() { ("name", "test"), ("value", 42) };
defer json.Dispose();

// TryGet - returns Result, use pattern matching
if (let val = json.TryGet("name"))
    Console.WriteLine(scope $"Name: {(StringView)val}");

// GetOrDefault - returns fallback value on failure
let missing = json.GetOrDefault("nonexistent", "default");
Console.WriteLine(scope $"Value: {(StringView)missing}");

// Works with arrays too
let arr = JsonArray() { 1, 2, 3 };
defer arr.Dispose();

if (let first = arr.TryGet(0))
    Console.WriteLine(scope $"First: {(int)first}");

let outOfBounds = arr.GetOrDefault(99, JsonNumber(0));  // Returns 0
```

### JSON Pointer (RFC 6901)

Navigate nested JSON structures using path expressions:

```cs
let jsonString = "{\"store\":{\"name\":\"My Shop\",\"products\":[{\"name\":\"Apple\"},{\"name\":\"Banana\"}]}}";
var result = Json.Deserialize(jsonString);
defer result.Dispose();

if (result case .Ok(let json))
{
    // Direct path access
    if (let storeName = json.GetByPointer("/store/name"))
        Console.WriteLine(scope $"Store: {(StringView)storeName}");

    // Access array elements
    if (let product = json.GetByPointer("/store/products/0/name"))
        Console.WriteLine(scope $"First product: {(StringView)product}");

    // GetByPointerOrDefault - returns fallback on failure
    let missing = json.GetByPointerOrDefault("/store/address", "N/A");
}
```

JSON Pointer escape sequences:
- `~0` represents `~`
- `~1` represents `/`

## API Reference

### Main Classes

- `Json` - Static methods for serialization and deserialization
- `Deserializer` - Configurable JSON parser
- `JsonWriter` - Output serialization
- `JsonReader` - Stream-based input parsing
- `JsonPointer` - RFC 6901 path-based navigation

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
