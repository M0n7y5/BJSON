using System;
using System.IO;
using BJSON;
using BJSON.Models;

namespace BJSON.Test
{
	/// Records whether external resolution was attempted, so a test can prove that a $ref
	/// resolved from a document already in memory.
	class RecordingSchemaResolver : ISchemaResolver
	{
		public bool WasCalled = false;

		public Result<JsonValue, JsonSchemaError> Resolve(StringView uri)
		{
			WasCalled = true;
			return .Err(.ExternalSchemaNotFound(uri));
		}
	}

	class SchemaTest
	{
		[Test(Name = "JSON Schema basic validation")]
		public static void T_SchemaBasic()
		{
			let schemaText = "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}";

			AssertValidates(schemaText, "{\"name\":\"Alice\"}", true, "An object carrying the required name");
			AssertValidates(schemaText, "{\"age\":30}", false, "An object missing the required name");
		}

		[Test(Name = "JSON Schema type validation")]
		public static void T_SchemaTypes()
		{
			AssertValidates("{\"type\":\"null\"}", "null", true, "null against type null");
			AssertValidates("{\"type\":\"null\"}", "123", false, "123 against type null");

			AssertValidates("{\"type\":\"boolean\"}", "true", true, "true against type boolean");
			AssertValidates("{\"type\":\"boolean\"}", "\"true\"", false, "the string \"true\" against type boolean");

			AssertValidates("{\"type\":\"string\"}", "\"hello\"", true, "a string against type string");
			AssertValidates("{\"type\":\"string\"}", "123", false, "123 against type string");

			AssertValidates("{\"type\":\"integer\"}", "42", true, "42 against type integer");
			AssertValidates("{\"type\":\"integer\"}", "3.14", false, "3.14 against type integer");

			AssertValidates("{\"type\":\"number\"}", "42", true, "42 against type number");
			AssertValidates("{\"type\":\"number\"}", "3.14", true, "3.14 against type number");
			AssertValidates("{\"type\":\"number\"}", "\"number\"", false, "a string against type number");

			AssertValidates("{\"type\":\"array\"}", "[1,2,3]", true, "an array against type array");
			AssertValidates("{\"type\":\"array\"}", "{\"key\":\"value\"}", false, "an object against type array");

			AssertValidates("{\"type\":\"object\"}", "{\"key\":\"value\"}", true, "an object against type object");
			AssertValidates("{\"type\":\"object\"}", "[1,2,3]", false, "an array against type object");
		}

		[Test(Name = "JSON Schema local $ref")]
		public static void T_SchemaLocalRef()
		{
			let schemaText = "{\"$defs\":{\"person\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}},\"$ref\":\"#/$defs/person\"}";

			AssertValidates(schemaText, "{\"name\":\"Bob\"}", true, "A local $ref to $defs/person");
		}

		[Test(Name = "JSON Schema external $ref (file)")]
		public static void T_SchemaExternalRef()
		{
			let currentDir = Directory.GetCurrentDirectory(.. scope .());
			let schemaPath = scope String();
			Path.InternalCombine(schemaPath, currentDir, "TestData", "person.schema.json");

			if (!File.Exists(schemaPath))
			{
				schemaPath.Clear();
				Path.InternalCombine(schemaPath, currentDir, "BJSON.Test", "TestData", "person.schema.json");
			}

			Test.Assert(File.Exists(schemaPath), scope $"External schema file not found at: {schemaPath}");

			var schemaRoot = JsonObject();
			schemaRoot.Add("$ref", JsonString(schemaPath));
			let schemaResult = JsonSchema.FromRoot(schemaRoot);

			if (schemaResult case .Err(let err))
			{
				let msg = scope String();
				err.ToString(msg);
				Test.Assert(false, scope $"Failed to parse schema: {msg}");
				return;
			}

			var instance = ParseInstanceOrFail("{\"name\":\"Eve\",\"age\":42}");
			defer instance.Dispose();

			let okValidate = schemaResult.Value.Validate(instance);
			defer okValidate.Dispose();

			if (okValidate case .Err(let valErr))
			{
				let msg = scope String();
				valErr.ToString(msg);
				Test.Assert(false, scope $"$ref validation error: {msg}");
				delete schemaResult.Value;
				return;
			}

			if (!okValidate.Value.IsValid)
			{
				if (okValidate.Value.Errors != null && okValidate.Value.Errors.Count > 0)
				{
					let firstError = okValidate.Value.Errors[0];
					Test.Assert(false, scope $"$ref validation failed: {firstError.Message} at {firstError.InstancePointer}");
				}
				else
				{
					Test.Assert(false, scope $"Validation returned IsValid=false but no errors. Schema path: {schemaPath}");
				}
			}

			delete schemaResult.Value;
		}

		[Test(Name = "JSON Schema object validation")]
		public static void T_SchemaObject()
		{
			{
				let schemaText = """
					{
						"type": "object",
						"properties": {
							"name": { "type": "string" },
							"age": { "type": "integer" }
						},
						"required": ["name"]
					}
					""";

				AssertValidates(schemaText, "{\"name\":\"Alice\"}", true, "An object with a string name");
				AssertValidates(schemaText, "{\"age\":30}", false, "An object without the required name");
			}

			{
				let schemaText = "{\"type\":\"object\",\"minProperties\":2,\"maxProperties\":3}";

				AssertValidates(schemaText, "{\"a\":1,\"b\":2}", true, "Two properties inside minProperties 2 and maxProperties 3");
				AssertValidates(schemaText, "{\"a\":1}", false, "One property below minProperties 2");
				AssertValidates(schemaText, "{\"a\":1,\"b\":2,\"c\":3,\"d\":4}", false, "Four properties above maxProperties 3");
			}

			{
				let schemaText = """
					{
						"type": "object",
						"properties": {
							"name": { "type": "string" }
						},
						"additionalProperties": false
					}
					""";

				AssertValidates(schemaText, "{\"name\":\"Alice\"}", true, "Only the declared property");
				AssertValidates(schemaText, "{\"name\":\"Alice\",\"extra\":\"value\"}", false, "An undeclared property against additionalProperties false");
			}
		}

		[Test(Name = "JSON Schema array validation")]
		public static void T_SchemaArray()
		{
			{
				let schemaText = "{\"type\":\"array\",\"items\":{\"type\":\"integer\"}}";

				AssertValidates(schemaText, "[1,2,3]", true, "All integer items");
				AssertValidates(schemaText, "[1,\"two\",3]", false, "A string among integer items");
			}

			{
				let schemaText = "{\"type\":\"array\",\"minItems\":2,\"maxItems\":3}";

				AssertValidates(schemaText, "[1,2]", true, "Two items inside minItems 2 and maxItems 3");
				AssertValidates(schemaText, "[1]", false, "One item below minItems 2");
				AssertValidates(schemaText, "[1,2,3,4]", false, "Four items above maxItems 3");
			}

			{
				let schemaText = "{\"type\":\"array\",\"uniqueItems\":true}";

				AssertValidates(schemaText, "[1,2,3]", true, "Distinct items against uniqueItems");
				AssertValidates(schemaText, "[1,2,1]", false, "A repeated item against uniqueItems");
			}

			{
				let schemaText = """
					{
						"type": "array",
						"prefixItems": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""";

				AssertValidates(schemaText, "[\"hello\",42]", true, "Positions matching prefixItems");
				AssertValidates(schemaText, "[42,\"hello\"]", false, "Positions swapped against prefixItems");
			}
		}

		[Test(Name = "JSON Schema numeric validation")]
		public static void T_SchemaNumeric()
		{
			{
				let schemaText = "{\"type\":\"number\",\"minimum\":0,\"maximum\":100}";

				AssertValidates(schemaText, "50", true, "50 inside minimum 0 and maximum 100");
				AssertValidates(schemaText, "0", true, "0 on the inclusive minimum");
				AssertValidates(schemaText, "100", true, "100 on the inclusive maximum");
				AssertValidates(schemaText, "-1", false, "-1 below minimum 0");
				AssertValidates(schemaText, "101", false, "101 above maximum 100");
			}

			{
				let schemaText = "{\"type\":\"number\",\"exclusiveMinimum\":0,\"exclusiveMaximum\":100}";

				AssertValidates(schemaText, "50", true, "50 inside the exclusive bounds");
				AssertValidates(schemaText, "0", false, "0 on exclusiveMinimum 0");
				AssertValidates(schemaText, "100", false, "100 on exclusiveMaximum 100");
			}
		}

		[Test(Name = "JSON Schema string validation")]
		public static void T_SchemaString()
		{
			let schemaText = "{\"type\":\"string\",\"minLength\":2,\"maxLength\":10}";

			AssertValidates(schemaText, "\"hello\"", true, "Five characters inside minLength 2 and maxLength 10");
			AssertValidates(schemaText, "\"h\"", false, "One character below minLength 2");
			AssertValidates(schemaText, "\"this is too long\"", false, "Sixteen characters above maxLength 10");
		}

		[Test(Name = "JSON Schema combining keywords")]
		public static void T_SchemaCombining()
		{
			{
				let schemaText = """
					{
						"allOf": [
							{ "type": "object" },
							{ "required": ["name"] }
						]
					}
					""";

				AssertValidates(schemaText, "{\"name\":\"Alice\"}", true, "An object with name against allOf");
				AssertValidates(schemaText, "{}", false, "An empty object against allOf");
			}

			{
				let schemaText = """
					{
						"anyOf": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""";

				AssertValidates(schemaText, "\"hello\"", true, "A string against anyOf string or integer");
				AssertValidates(schemaText, "42", true, "An integer against anyOf string or integer");
				AssertValidates(schemaText, "true", false, "A boolean against anyOf string or integer");
			}

			{
				let schemaText = """
					{
						"oneOf": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""";

				AssertValidates(schemaText, "\"hello\"", true, "A string against oneOf string or integer");
				AssertValidates(schemaText, "42", true, "An integer against oneOf string or integer");
			}

			{
				let schemaText = "{\"not\":{\"type\":\"string\"}}";

				AssertValidates(schemaText, "123", true, "A number against not string");
				AssertValidates(schemaText, "\"string\"", false, "A string against not string");
			}
		}

		[Test(Name = "JSON Schema conditional validation")]
		public static void T_SchemaConditional()
		{
			let schemaText = """
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
				""";

			AssertValidates(schemaText, "{\"role\":\"admin\",\"permissions\":[\"read\",\"write\"]}", true, "An admin with permissions takes the then branch");
			AssertValidates(schemaText, "{\"role\":\"admin\"}", false, "An admin without permissions breaks the then branch");
			AssertValidates(schemaText, "{\"role\":\"user\",\"department\":\"IT\"}", true, "A user with a department takes the else branch");
			AssertValidates(schemaText, "{\"role\":\"user\"}", false, "A user without a department breaks the else branch");
		}

		[Test(Name = "JSON Schema constants")]
		public static void T_SchemaConstants()
		{
			{
				let schemaText = "{\"enum\":[\"red\",\"green\",\"blue\"]}";

				AssertValidates(schemaText, "\"red\"", true, "A listed enum member");
				AssertValidates(schemaText, "\"yellow\"", false, "A value outside the enum");
			}

			{
				let schemaText = "{\"const\":\"active\"}";

				AssertValidates(schemaText, "\"active\"", true, "The const value");
				AssertValidates(schemaText, "\"inactive\"", false, "A value differing from the const");
			}
		}

		[Test(Name = "JSON Schema boolean schemas")]
		public static void T_SchemaBoolean()
		{
			AssertValidates("true", "null", true, "null against the true schema");
			AssertValidates("true", "123", true, "123 against the true schema");
			AssertValidates("true", "\"anything\"", true, "a string against the true schema");

			AssertValidates("false", "null", false, "null against the false schema");
			AssertValidates("false", "123", false, "123 against the false schema");

			{
				let schemaText = """
					{
						"type": "object",
						"properties": {
							"alwaysValid": true,
							"neverValid": false
						}
					}
					""";

				AssertValidates(schemaText, "{\"alwaysValid\":\"anything\"}", true, "A property held by the true schema");
				AssertValidates(schemaText, "{\"neverValid\":\"anything\"}", false, "A property held by the false schema");
			}
		}

		[Test(Name = "JSON Schema $id and $anchor")]
		public static void T_SchemaIdAnchor()
		{
			{
				let schemaText = """
					{
						"type": "object",
						"properties": {
							"name": { "type": "string" }
						}
					}
					""";

				AssertValidates(schemaText, "{\"name\":\"test\"}", true, "A schema without $id");
			}

			{
				let schemaText = """
					{
						"$defs": {
							"person": {
								"$anchor": "person",
								"type": "object",
								"properties": {
									"name": { "type": "string" }
								}
							}
						},
						"$ref": "#person"
					}
					""";

				AssertValidates(schemaText, "{\"name\":\"Alice\"}", true, "A $ref to an $anchor");
			}
		}

		[Test(Name = "JSON Schema recursive $ref")]
		public static void T_SchemaRecursiveRef()
		{
			let schemaText = """
				{
					"$defs": {
						"node": {
							"type": "object",
							"properties": {
								"value": { "type": "integer" },
								"next": { "$ref": "#/$defs/node" }
							}
						}
					},
					"$ref": "#/$defs/node"
				}
				""";

			AssertValidates(schemaText, "{\"value\":1,\"next\":{\"value\":2,\"next\":{\"value\":3}}}", true, "Two levels of recursion should be valid");
			AssertValidates(schemaText, "{\"value\":1,\"next\":{\"value\":\"two\"}}", false, "A nested type mismatch should be invalid");
		}

		[Test(Name = "JSON Schema $ref cycle detection")]
		public static void T_SchemaRefCycle()
		{
			let schema = ParseSchemaOrFail("""
				{
					"$defs": {
						"a": { "$ref": "#/$defs/b" },
						"b": { "$ref": "#/$defs/a" }
					},
					"$ref": "#/$defs/a"
				}
				""");
			defer delete schema;

			var instance = ParseInstanceOrFail("{}");
			defer instance.Dispose();

			let result = schema.Validate(instance);
			defer result.Dispose();

			bool cycleDetected = false;
			if (result case .Err(let err))
			{
				if (err case .RefCycleDetected)
					cycleDetected = true;
			}

			let summary = Summarize(result, .. scope String());
			Test.Assert(cycleDetected, scope $"A $ref reaching itself must report a cycle, got {summary}");
		}

		[Test(Name = "JSON Schema $ref to an embedded $id")]
		public static void T_SchemaEmbeddedIdRef()
		{
			let resolver = scope RecordingSchemaResolver();
			let schemaResult = JsonSchema.Parse("""
				{
					"$id": "https://example.com/root",
					"$defs": {
						"name": {
							"$id": "https://example.com/name",
							"type": "string",
							"minLength": 2
						}
					},
					"$ref": "https://example.com/name"
				}
				""", "", resolver);
			Test.Assert(schemaResult case .Ok, "Failed to parse the schema with an embedded $id");

			let schema = schemaResult.Value;
			defer delete schema;

			{
				var instance = ParseInstanceOrFail("\"Ada\"");
				defer instance.Dispose();

				let result = schema.Validate(instance);
				defer result.Dispose();
				let summary = Summarize(result, .. scope String());
				Test.Assert(result case .Ok(let validation) && validation.IsValid, scope $"The embedded $id should resolve locally, got {summary}");
			}

			{
				var instance = ParseInstanceOrFail("\"A\"");
				defer instance.Dispose();

				let result = schema.Validate(instance);
				defer result.Dispose();
				let summary = Summarize(result, .. scope String());
				Test.Assert(result case .Ok(let validation) && !validation.IsValid, scope $"minLength of the embedded schema should apply, got {summary}");
			}

			Test.Assert(!resolver.WasCalled, scope $"The embedded $id must resolve from the id index, resolver called: {resolver.WasCalled}");
		}

		[Test(Name = "JSON Schema multipleOf")]
		public static void T_SchemaMultipleOf()
		{
			AssertValidates("{\"type\":\"number\",\"multipleOf\":3}", "9", true, "9 is a multiple of 3");
			AssertValidates("{\"type\":\"number\",\"multipleOf\":3}", "10", false, "10 is not a multiple of 3");

			// 0.3 divided by 0.1 is not exact in binary floating point
			AssertValidates("{\"type\":\"number\",\"multipleOf\":0.1}", "0.3", true, "0.3 is a multiple of 0.1");
			AssertValidates("{\"type\":\"number\",\"multipleOf\":0.1}", "0.35", false, "0.35 is not a multiple of 0.1");
		}

		[Test(Name = "JSON Schema contains with minContains and maxContains")]
		public static void T_SchemaContains()
		{
			{
				let schemaText = "{\"type\":\"array\",\"contains\":{\"type\":\"integer\"},\"minContains\":2,\"maxContains\":3}";

				AssertValidates(schemaText, "[1,\"a\",2]", true, "Two integers satisfy minContains 2");
				AssertValidates(schemaText, "[\"a\",1]", false, "One integer is below minContains 2");
				AssertValidates(schemaText, "[1,2,3,4]", false, "Four integers exceed maxContains 3");
			}

			// minContains defaults to 1
			{
				let schemaText = "{\"type\":\"array\",\"contains\":{\"const\":\"x\"}}";

				AssertValidates(schemaText, "[\"y\",\"x\"]", true, "The array contains x");
				AssertValidates(schemaText, "[\"y\",\"z\"]", false, "The array has no x");
			}
		}

		[Test(Name = "JSON Schema propertyNames")]
		public static void T_SchemaPropertyNames()
		{
			let schemaText = "{\"type\":\"object\",\"propertyNames\":{\"maxLength\":3}}";

			AssertValidates(schemaText, "{\"abc\":1,\"de\":2}", true, "Every property name fits maxLength 3");
			AssertValidates(schemaText, "{\"abc\":1,\"defg\":2}", false, "The name defg breaks maxLength 3");
		}

		[Test(Name = "JSON Schema string length counts code points")]
		public static void T_SchemaStringCodePointLength()
		{
			// "a\u00f1b" is three code points held in four UTF-8 bytes
			AssertValidates("{\"type\":\"string\",\"maxLength\":3}", "\"a\\u00f1b\"", true, "Three code points fit maxLength 3");
			AssertValidates("{\"type\":\"string\",\"minLength\":4}", "\"a\\u00f1b\"", false, "Three code points are below minLength 4");
		}

		[Test(Name = "JSON Schema const with an integer above 2^53")]
		public static void T_SchemaLargeIntegerConst()
		{
			// 9007199254740992 and 9007199254740993 collapse to the same double
			AssertValidates("{\"const\":9007199254740993}", "9007199254740993", true, "9007199254740993 matches the const");
			AssertValidates("{\"const\":9007199254740993}", "9007199254740992", false, "9007199254740992 differs from the const");

			AssertValidates("{\"const\":1}", "1.0", true, "1.0 equals the const 1");
		}

		[Test(Name = "Regression: a schema error reference survives the resolution that built it")]
		public static void T_SchemaErrorReferenceOutlivesResolution()
		{
			let schemaText = """
				{"$ref": "missing-schema.json"}
				""";

			let schema = ParseSchemaOrFail(schemaText);
			defer delete schema;

			var instance = ParseInstanceOrFail("{}");
			defer instance.Dispose();

			let result = schema.Validate(instance);
			Test.Assert(result case .Err(let err), "an unresolvable $ref must fail validation");

			let text = scope String();
			err.ToString(text);
			Test.Assert(text.Contains("missing-schema.json"), scope $"error text lost the reference: '{text}'");
		}

		/// Compiles a schema, failing the test instead of returning when it does not compile.
		/// @param schemaText The schema document.
		/// @returns The compiled schema, which the caller must delete.
		private static JsonSchema ParseSchemaOrFail(StringView schemaText)
		{
			let result = JsonSchema.Parse(schemaText);
			Test.Assert(result case .Ok, scope $"The schema must compile: {schemaText}");

			return result.Value;
		}

		/// Parses an instance document, failing the test instead of returning when it does not parse.
		/// @param instanceText The instance document.
		/// @returns The parsed tree, which the caller must dispose.
		private static JsonValue ParseInstanceOrFail(StringView instanceText)
		{
			let result = Json.Deserialize(instanceText);
			Test.Assert(result case .Ok, scope $"The instance must parse: {instanceText}");

			return result.Value;
		}

		/// Compiles the schema, parses the instance, and asserts the validity the caller expects.
		/// @param schemaText The schema document.
		/// @param instanceText The instance document.
		/// @param expectValid Whether validation must report the instance valid.
		/// @param message What the case proves, prefixed to the failure text.
		private static void AssertValidates(StringView schemaText, StringView instanceText, bool expectValid, StringView message)
		{
			let schema = ParseSchemaOrFail(schemaText);
			defer delete schema;

			var instance = ParseInstanceOrFail(instanceText);
			defer instance.Dispose();

			let result = schema.Validate(instance);
			defer result.Dispose();

			let summary = Summarize(result, .. scope String());
			if (result case .Ok(let validation))
				Test.Assert(validation.IsValid == expectValid, scope $"{message}: expected {expectValid ? "valid" : "invalid"}, got {summary}");
			else
				Test.Assert(false, scope $"{message}: validation must complete, got {summary}");
		}

		private static void Summarize(Result<SchemaValidationResult, JsonSchemaError> result, String buffer)
		{
			if (result case .Err(let err))
			{
				buffer.Append("error ");
				err.ToString(buffer);
				return;
			}

			let validation = result.Value;
			buffer.AppendF("IsValid={}", validation.IsValid);
			if (validation.Errors != null && validation.Errors.Count > 0)
				buffer.AppendF(", first error: {} at {}", validation.Errors[0].Message, validation.Errors[0].InstancePointer);
		}
	}
}
