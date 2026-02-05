using System;
using System.IO;
using System.Diagnostics;
using BJSON;
using BJSON.Models;

namespace BJSON.Test
{
	class SchemaTest
	{
		[Test(Name = "JSON Schema basic validation")]
		public static void T_SchemaBasic()
		{
			let schemaText = "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}";
			let schemaResult = JsonSchema.Parse(schemaText);
			Test.Assert(schemaResult case .Ok, "Failed to parse schema");

			let okInstance = Json.Deserialize("{\"name\":\"Alice\"}");
			defer okInstance.Dispose();
			Test.Assert(okInstance case .Ok, "Failed to parse instance");
			let okValidate = schemaResult.Value.Validate(okInstance.Value);
			Test.Assert(okValidate case .Ok, "Validation failed");
			Test.Assert(okValidate.Value.IsValid, "Instance should be valid");

			let badInstance = Json.Deserialize("{\"age\":30}");
			defer badInstance.Dispose();
			Test.Assert(badInstance case .Ok, "Failed to parse instance");
			let badValidate = schemaResult.Value.Validate(badInstance.Value);
			Test.Assert(badValidate case .Ok, "Validation failed");
			Test.Assert(!badValidate.Value.IsValid, "Instance should be invalid");
			
			delete schemaResult.Value;
		}

		[Test(Name = "JSON Schema type validation")]
		public static void T_SchemaTypes()
		{
			// Test null type
			{
				let schema = JsonSchema.Parse("{\"type\":\"null\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("null");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("123");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}

			// Test boolean type
			{
				let schema = JsonSchema.Parse("{\"type\":\"boolean\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("true");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("\"true\"");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}

			// Test string type
			{
				let schema = JsonSchema.Parse("{\"type\":\"string\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("\"hello\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("123");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}

			// Test integer type
			{
				let schema = JsonSchema.Parse("{\"type\":\"integer\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("42");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("3.14");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}

			// Test number type
			{
				let schema = JsonSchema.Parse("{\"type\":\"number\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("42");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("3.14");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
				}
				let json3 = Json.Deserialize("\"number\"");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				delete schema.Value;
			}

			// Test array type
			{
				let schema = JsonSchema.Parse("{\"type\":\"array\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("[1,2,3]");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("{\"key\":\"value\"}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}

			// Test object type
			{
				let schema = JsonSchema.Parse("{\"type\":\"object\"}");
				Test.Assert(schema case .Ok);
				let json1 = Json.Deserialize("{\"key\":\"value\"}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				let json2 = Json.Deserialize("[1,2,3]");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema local $ref")]
		public static void T_SchemaLocalRef()
		{
			let schemaText = "{\"$defs\":{\"person\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}},\"required\":[\"name\"]}},\"$ref\":\"#/$defs/person\"}";
			let schemaResult = JsonSchema.Parse(schemaText);
			Test.Assert(schemaResult case .Ok, "Failed to parse schema");

			let okInstance = Json.Deserialize("{\"name\":\"Bob\"}");
			defer okInstance.Dispose();
			Test.Assert(okInstance case .Ok, "Failed to parse instance");
			let okValidate = schemaResult.Value.Validate(okInstance.Value);
			Test.Assert(okValidate case .Ok, "Validation failed");
			Test.Assert(okValidate.Value.IsValid, "Instance should be valid");
			
			delete schemaResult.Value;
		}

		[Test(Name = "JSON Schema external $ref (file)")]
		public static void T_SchemaExternalRef()
		{
			let currentDir = Directory.GetCurrentDirectory(.. scope .());
			let schemaPath = scope String();
			schemaPath.Append(currentDir);
			schemaPath.Append("\\TestData\\person.schema.json");
			
			if (!File.Exists(schemaPath))
			{
				schemaPath.Clear();
				schemaPath.Append(currentDir);
				schemaPath.Append("\\BJSON.Test\\TestData\\person.schema.json");
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

			let okInstance = Json.Deserialize("{\"name\":\"Eve\",\"age\":42}");
			defer okInstance.Dispose();
			Test.Assert(okInstance case .Ok, "Failed to parse instance");
			let okValidate = schemaResult.Value.Validate(okInstance.Value);
			
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
			// Test properties and required
			{
				let schema = JsonSchema.Parse("""
					{
						"type": "object",
						"properties": {
							"name": { "type": "string" },
							"age": { "type": "integer" }
						},
						"required": ["name"]
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("{\"name\":\"Alice\"}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("{\"age\":30}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test minProperties and maxProperties
			{
				let schema = JsonSchema.Parse("{\"type\":\"object\",\"minProperties\":2,\"maxProperties\":3}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("{\"a\":1,\"b\":2}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("{\"a\":1}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				let json3 = Json.Deserialize("{\"a\":1,\"b\":2,\"c\":3,\"d\":4}");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				
				delete schema.Value;
			}

			// Test additionalProperties
			{
				let schema = JsonSchema.Parse("""
					{
						"type": "object",
						"properties": {
							"name": { "type": "string" }
						},
						"additionalProperties": false
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("{\"name\":\"Alice\"}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("{\"name\":\"Alice\",\"extra\":\"value\"}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema array validation")]
		public static void T_SchemaArray()
		{
			// Test items
			{
				let schema = JsonSchema.Parse("{\"type\":\"array\",\"items\":{\"type\":\"integer\"}}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("[1,2,3]");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("[1,\"two\",3]");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test minItems and maxItems
			{
				let schema = JsonSchema.Parse("{\"type\":\"array\",\"minItems\":2,\"maxItems\":3}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("[1,2]");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("[1]");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				let json3 = Json.Deserialize("[1,2,3,4]");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				
				delete schema.Value;
			}

			// Test uniqueItems
			{
				let schema = JsonSchema.Parse("{\"type\":\"array\",\"uniqueItems\":true}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("[1,2,3]");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("[1,2,1]");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test prefixItems
			{
				let schema = JsonSchema.Parse("""
					{
						"type": "array",
						"prefixItems": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("[\"hello\",42]");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("[42,\"hello\"]");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema numeric validation")]
		public static void T_SchemaNumeric()
		{
			// Test minimum and maximum
			{
				let schema = JsonSchema.Parse("{\"type\":\"number\",\"minimum\":0,\"maximum\":100}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("50");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("0");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
				}
				
				let json3 = Json.Deserialize("100");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && r3.IsValid);
				}
				
				let json4 = Json.Deserialize("-1");
				defer json4.Dispose();
				if (json4 case .Ok(let val4))
				{
					let result4 = schema.Value.Validate(val4);
					Test.Assert(result4 case .Ok(let r4) && !r4.IsValid);
				}
				
				let json5 = Json.Deserialize("101");
				defer json5.Dispose();
				if (json5 case .Ok(let val5))
				{
					let result5 = schema.Value.Validate(val5);
					Test.Assert(result5 case .Ok(let r5) && !r5.IsValid);
				}
				
				delete schema.Value;
			}

			// Test exclusiveMinimum and exclusiveMaximum
			{
				let schema = JsonSchema.Parse("{\"type\":\"number\",\"exclusiveMinimum\":0,\"exclusiveMaximum\":100}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("50");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("0");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				let json3 = Json.Deserialize("100");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema string validation")]
		public static void T_SchemaString()
		{
			// Test minLength and maxLength
			{
				let schema = JsonSchema.Parse("{\"type\":\"string\",\"minLength\":2,\"maxLength\":10}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("\"hello\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("\"h\"");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				let json3 = Json.Deserialize("\"this is too long\"");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema combining keywords")]
		public static void T_SchemaCombining()
		{
			// Test allOf
			{
				let schema = JsonSchema.Parse("""
					{
						"allOf": [
							{ "type": "object" },
							{ "required": ["name"] }
						]
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("{\"name\":\"Alice\"}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("{}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test anyOf
			{
				let schema = JsonSchema.Parse("""
					{
						"anyOf": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("\"hello\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("42");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
				}
				
				let json3 = Json.Deserialize("true");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && !r3.IsValid);
				}
				
				delete schema.Value;
			}

			// Test oneOf
			{
				let schema = JsonSchema.Parse("""
					{
						"oneOf": [
							{ "type": "string" },
							{ "type": "integer" }
						]
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("\"hello\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("42");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test not
			{
				let schema = JsonSchema.Parse("{\"not\":{\"type\":\"string\"}}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("123");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("\"string\"");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema conditional validation")]
		public static void T_SchemaConditional()
		{
			let schema = JsonSchema.Parse("""
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
				""");
			Test.Assert(schema case .Ok);
			
			// Admin needs permissions
			let json1 = Json.Deserialize("{\"role\":\"admin\",\"permissions\":[\"read\",\"write\"]}");
			defer json1.Dispose();
			if (json1 case .Ok(let val1))
			{
				let result1 = schema.Value.Validate(val1);
				Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
			}
			
			let json2 = Json.Deserialize("{\"role\":\"admin\"}");
			defer json2.Dispose();
			if (json2 case .Ok(let val2))
			{
				let result2 = schema.Value.Validate(val2);
				Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
			}
			
			// Non-admin needs department
			let json3 = Json.Deserialize("{\"role\":\"user\",\"department\":\"IT\"}");
			defer json3.Dispose();
			if (json3 case .Ok(let val3))
			{
				let result3 = schema.Value.Validate(val3);
				Test.Assert(result3 case .Ok(let r3) && r3.IsValid);
			}
			
			let json4 = Json.Deserialize("{\"role\":\"user\"}");
			defer json4.Dispose();
			if (json4 case .Ok(let val4))
			{
				let result4 = schema.Value.Validate(val4);
				Test.Assert(result4 case .Ok(let r4) && !r4.IsValid);
			}
			
			delete schema.Value;
		}

		[Test(Name = "JSON Schema constants")]
		public static void T_SchemaConstants()
		{
			// Test enum
			{
				let schema = JsonSchema.Parse("{\"enum\":[\"red\",\"green\",\"blue\"]}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("\"red\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("\"yellow\"");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test const
			{
				let schema = JsonSchema.Parse("{\"const\":\"active\"}");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("\"active\"");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("\"inactive\"");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema boolean schemas")]
		public static void T_SchemaBoolean()
		{
			// Test true schema (always valid)
			{
				let schema = JsonSchema.Parse("true");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("null");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("123");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
				}
				
				let json3 = Json.Deserialize("\"anything\"");
				defer json3.Dispose();
				if (json3 case .Ok(let val3))
				{
					let result3 = schema.Value.Validate(val3);
					Test.Assert(result3 case .Ok(let r3) && r3.IsValid);
				}
				
				delete schema.Value;
			}

			// Test false schema (always invalid)
			{
				let schema = JsonSchema.Parse("false");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("null");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && !r1.IsValid);
				}
				
				let json2 = Json.Deserialize("123");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}

			// Test boolean schema in properties
			{
				let schema = JsonSchema.Parse("""
					{
						"type": "object",
						"properties": {
							"alwaysValid": true,
							"neverValid": false
						}
					}
					""");
				Test.Assert(schema case .Ok);
				
				let json1 = Json.Deserialize("{\"alwaysValid\":\"anything\"}");
				defer json1.Dispose();
				if (json1 case .Ok(let val1))
				{
					let result1 = schema.Value.Validate(val1);
					Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
				}
				
				let json2 = Json.Deserialize("{\"neverValid\":\"anything\"}");
				defer json2.Dispose();
				if (json2 case .Ok(let val2))
				{
					let result2 = schema.Value.Validate(val2);
					Test.Assert(result2 case .Ok(let r2) && !r2.IsValid);
				}
				
				delete schema.Value;
			}
		}

		[Test(Name = "JSON Schema $id and $anchor")]
		public static void T_SchemaIdAnchor()
		{
			// Test $id for base URI
			let schema = JsonSchema.Parse("""
				{
					"type": "object",
					"properties": {
						"name": { "type": "string" }
					}
				}
				""");
			Test.Assert(schema case .Ok);
			
			let json1 = Json.Deserialize("{\"name\":\"test\"}");
			defer json1.Dispose();
			if (json1 case .Ok(let val1))
			{
				let result1 = schema.Value.Validate(val1);
				Test.Assert(result1 case .Ok(let r1) && r1.IsValid);
			}
			
			delete schema.Value;

			// Test $anchor
			let schemaWithAnchor = JsonSchema.Parse("""
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
				""");
			Test.Assert(schemaWithAnchor case .Ok);
			
			let json2 = Json.Deserialize("{\"name\":\"Alice\"}");
			defer json2.Dispose();
			if (json2 case .Ok(let val2))
			{
				let result2 = schemaWithAnchor.Value.Validate(val2);
				Test.Assert(result2 case .Ok(let r2) && r2.IsValid);
			}
			
			delete schemaWithAnchor.Value;
		}
	}
}
