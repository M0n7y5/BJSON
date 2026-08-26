using System;
using System.Collections;

namespace BJSON.SchemaCodeGen;

/// Kind of a parsed schema. SchemaParser sets it from `type`, from `enum`, from `$ref`, or, when
/// no `type` keyword is present, from the members the schema carries.
enum SchemaType
{
	/// `type: object`, or a typeless schema carrying `properties` or `allOf`. Generates a class.
	Object,
	/// `type: array`, or a typeless schema carrying `items`. Generates a List of the element type.
	Array,
	/// `type: string`. Generates a heap allocated String field.
	String,
	/// `type: integer`. Generates int32 or int64, following --integer-type.
	Integer,
	/// `type: number`. Generates float or double, following --number-type.
	Number,
	/// `type: boolean`. Generates bool.
	Boolean,
	/// `enum` listing string values. Generates a Beef enum, and outranks a `type` keyword on the
	/// same schema.
	Enum,
	/// `$ref`. Carries no type of its own: it reports its target through Resolved once
	/// TypeResolver.Resolve has filled ReferencedSchema.
	Ref,
	/// No usable type: no `type` keyword and no members, `type: null`, or a `true` property
	/// schema. Generates JsonValue, or a nullable integer when `type` also listed "null".
	Any
}

/// One schema of the parsed document.
/// Ownership: the node list that SchemaParser.Parse fills owns every SchemaModel, and the caller
/// of Parse owns that list. A node owns only its own strings, the PropertyModel entries of
/// Properties, the strings in Required and EnumValues, and the AllOf list container. Items, the
/// AllOf entries and ReferencedSchema are non owning pointers to other nodes of that same list, so
/// nothing frees a node through them.
class SchemaModel
{
	/// Beef type name, taken from `title`, from the declaring property, or from the definition key.
	/// TypeResolver.Resolve makes it unique across the run.
	public String Name = new String() ~ delete _;
	/// Schema `description`, emitted as a doc comment.
	public String Description = new String() ~ delete _;
	/// Kind of this schema, which decides the members below that carry data.
	public SchemaType Type;
	/// Whether `type` listed "null" beside the type, which makes a value type field nullable.
	public bool IsNullable;
	/// Object properties in the order the document declares them, which is the order the generated
	/// fields keep. Owns them. FindProperty looks one up by its raw JSON key.
	public List<PropertyModel> Properties = new .() ~ DeleteContainerAndItems!(_);
	/// Raw JSON keys listed by `required`. Owns the strings.
	public List<String> Required = new .() ~ DeleteContainerAndItems!(_);
	/// Values listed by `enum`. Owns the strings.
	public List<String> EnumValues = new .() ~ DeleteContainerAndItems!(_);
	/// Element schema of an array. Non owning: the node list owns it.
	public SchemaModel Items;
	/// `allOf` members in document order. Owns the list, not the entries: the node list owns those.
	/// The first entry that resolves to an object becomes the Beef base class, and TypeResolver
	/// copies the properties of the later entries into this node.
	public List<SchemaModel> AllOf = new .() ~ delete _;
	/// Name of the Beef base class, filled by TypeResolver from the first `allOf` member that
	/// resolves to an object. Empty when the type has no base.
	public String BaseTypeName = new String() ~ delete _;
	/// Whether this node becomes a generated file. TypeResolver clears it for an inline `allOf`
	/// member whose properties it copied into the deriving type: the copies leave that member with
	/// no reader, so a file for it would declare a class nothing names.
	public bool Generate = true;
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

	/// Finds the property declaring a raw JSON key, compared case sensitively.
	/// @param jsonName The raw JSON key.
	/// @returns The property, or null when this schema does not declare it. Non owning: the
	///          Properties list owns it.
	public PropertyModel FindProperty(StringView jsonName)
	{
		for (var prop in this.Properties)
		{
			if (prop.JsonName.Equals(jsonName, .Ordinal))
			{
				return prop;
			}
		}

		return null;
	}
}

/// One property of an object schema. Owned by the Properties list that holds it, so it is freed
/// with the SchemaModel that owns that list. Owns its own strings.
class PropertyModel
{
	/// Beef field name derived from the JSON key. CodeGenerator numbers it when another property of
	/// the same type already took that name.
	public String Name = new String() ~ delete _;
	/// Raw JSON key, emitted as [JsonPropertyName] when it differs from the field name.
	public String JsonName = new String() ~ delete _;
	/// Schema of the property value. Non owning: the node list owns it. A property that
	/// TypeResolver copied in from a further `allOf` member is a separate PropertyModel pointing at
	/// the same node, so neither of them frees it.
	public SchemaModel Schema;
	/// Whether `required` names this property, emitted as [JsonRequired]. A `required` entry on a
	/// derived schema instead marks the property on the base schema that declares it.
	public bool IsRequired;
	/// Property `description`, emitted as a doc comment unless --skip-docs.
	public String Description = new String() ~ delete _;
}
