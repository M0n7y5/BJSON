using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

enum SchemaType
{
	Object,
	Array,
	String,
	Integer,
	Number,
	Boolean,
	Enum,
	Ref,
	Any
}

/// One schema of the parsed document.
/// Ownership: the node list that SchemaParser.Parse fills owns every SchemaModel, and the caller
/// of Parse owns that list. A node owns only its own strings, the keys and PropertyModel values of
/// Properties, and the strings in Required and EnumValues. Items, the AllOf entries and
/// ReferencedSchema are non owning pointers to other nodes of that same list, so nothing frees a
/// node through them.
class SchemaModel
{
	/// Beef type name, taken from `title`, from the declaring property, or from the definition key.
	/// TypeResolver.Resolve makes it unique across the run.
	public String Name = new String() ~ delete _;
	/// Schema `description`, emitted as a doc comment.
	public String Description = new String() ~ delete _;
	public SchemaType Type;
	public bool IsNullable;
	/// Object properties keyed by the raw JSON key. Owns both the keys and the values.
	public Dictionary<String, PropertyModel> Properties = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
	/// Raw JSON keys listed by `required`. Owns the strings.
	public List<String> Required = new .() ~ DeleteContainerAndItems!(_);
	/// Values listed by `enum`. Owns the strings.
	public List<String> EnumValues = new .() ~ DeleteContainerAndItems!(_);
	/// Element schema of an array. Non owning: the node list owns it.
	public SchemaModel Items;
	/// `allOf` members in document order. Non owning: the node list owns them.
	public List<SchemaModel> AllOf = new .() ~ delete _;
	/// Target of `$ref`, filled by TypeResolver.Resolve. Non owning: the node list owns it.
	public SchemaModel ReferencedSchema;
	/// Raw `$ref` text, empty unless Type is .Ref.
	public String RefPath = new String() ~ delete _;
	/// JSON Pointer (RFC 6901) of this schema inside the document, prefixed with '#', for example
	/// "#", "#/definitions/Address" or "#/properties/name". `$ref` resolution matches it exactly.
	public String Pointer = new String() ~ delete _;

	/// The schema this node stands for: a `$ref` with a resolved target reports the target, every
	/// other node reports itself. Non owning.
	public SchemaModel Resolved => ((this.Type == .Ref) && (this.ReferencedSchema != null)) ? this.ReferencedSchema : this;
}

/// One property of an object schema, owned by the SchemaModel that declares it.
class PropertyModel
{
	/// Beef field name.
	public String Name = new String() ~ delete _;
	/// Raw JSON key, emitted as [JsonPropertyName] when it differs from Name.
	public String JsonName = new String() ~ delete _;
	/// Schema of the property value. Non owning: the node list owns it, and a property inherited
	/// through `allOf` shares the base property's node.
	public SchemaModel Schema;
	public bool IsRequired;
	public String DefaultValue = new String() ~ delete _;
	public String Description = new String() ~ delete _;
}
