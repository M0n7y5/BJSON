using System;
using System.Collections;
using System.IO;
using BJSON.SchemaCodeGen;

namespace BJSON.SchemaCodeGen.Tests;

class SchemaCodeGenTests
{
	[Test(Name = "SchemaCodeGen flattens allOf fields")]
	public static void T_FlattensAllOf()
	{
		let schemaText = "{\"title\":\"Employee\",\"type\":\"object\",\"allOf\":[{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}}},{\"type\":\"object\",\"properties\":{\"employee_id\":{\"type\":\"integer\"}}}],\"required\":[\"name\",\"employee_id\"]}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Employee");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected schema to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(schemas.Count == 1, scope $"Expected one generated type, got {schemas.Count}");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(schemas[0]);
				defer delete code;

				Test.Assert(code.Contains("class Employee\n{"), scope $"Expected flattened Employee class. Code:\n{code}");
				Test.Assert(!code.Contains("class Employee :"), scope $"allOf should not generate inheritance. Code:\n{code}");
				Test.Assert(code.Contains("[JsonRequired]\n\tpublic String Name"), scope $"Expected required name field. Code:\n{code}");
				Test.Assert(code.Contains("[JsonPropertyName(\"employee_id\")]\n\tpublic int64 EmployeeId"), scope $"Expected employee_id field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves definitions and $defs refs")]
	public static void T_ResolvesDefinitions()
	{
		let schemaText = "{\"title\":\"Catalog\",\"type\":\"object\",\"properties\":{\"primaryProduct\":{\"$ref\":\"#/$defs/Product\"},\"address\":{\"$ref\":\"#/definitions/Address\"}},\"$defs\":{\"Product\":{\"type\":\"object\",\"properties\":{\"sku\":{\"type\":\"string\"}}}},\"definitions\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Catalog");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected internal refs to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(schemas.Count == 3, scope $"Expected three generated types, got {schemas.Count}");

				SchemaModel catalog = null;
				for (var schema in schemas)
				{
					if (schema.Name == "Catalog")
					{
						catalog = schema;
					}
				}

				Test.Assert(catalog != null, "Expected Catalog type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(catalog);
				defer delete code;

				Test.Assert(code.Contains("public Product PrimaryProduct = new .() ~ delete _;"), scope $"Expected $defs ref field. Code:\n{code}");
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected definitions ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves anchor refs")]
	public static void T_ResolvesAnchorRef()
	{
		let schemaText = "{\"title\":\"Catalog\",\"type\":\"object\",\"properties\":{\"owner\":{\"$ref\":\"#person\"}},\"$defs\":{\"Person\":{\"$anchor\":\"person\",\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"}}}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Catalog");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected anchor ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let catalog = FindSchema(schemas, "Catalog");
				Test.Assert(catalog != null, "Expected Catalog type");
				Test.Assert(FindSchema(schemas, "Person") != null, "Expected Person type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(catalog);
				defer delete code;
				Test.Assert(code.Contains("public Person Owner = new .() ~ delete _;"), scope $"Expected anchor ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves external anchor refs")]
	public static void T_ResolvesExternalAnchorRef()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"common.schema.json#address\"}}}";
		let commonText = "{\"$defs\":{\"Address\":{\"$anchor\":\"address\",\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected external anchor ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let customer = FindSchema(schemas, "Customer");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected external anchor ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves embedded id refs")]
	public static void T_ResolvesEmbeddedIdRef()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "catalog.schema.json", rootPath);

		let schemaText = "{\"title\":\"Catalog\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"schemas/address.schema.json\"}},\"$defs\":{\"Address\":{\"$id\":\"schemas/address.schema.json\",\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, schemaText) case .Ok, "Expected root fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Catalog", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected embedded id ref to resolve without loading a file");

			if (resolveResult case .Ok(let schemas))
			{
				let catalog = FindSchema(schemas, "Catalog");
				Test.Assert(catalog != null, "Expected Catalog type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(catalog);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected embedded id ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen uses id base for nested refs")]
	public static void T_IdBaseAppliesToNestedRefs()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "catalog.schema.json", rootPath);

		let schemaText = "{\"title\":\"Catalog\",\"type\":\"object\",\"properties\":{\"container\":{\"$ref\":\"schemas/container.schema.json\"}},\"$defs\":{\"Container\":{\"$id\":\"schemas/container.schema.json\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"#address\"}},\"$defs\":{\"Address\":{\"$anchor\":\"address\",\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}}}";
		Test.Assert(File.WriteAllText(rootPath, schemaText) case .Ok, "Expected root fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Catalog", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected nested id-base anchor ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let catalog = FindSchema(schemas, "Catalog");
				let container = FindSchema(schemas, "Container");
				Test.Assert(catalog != null, "Expected Catalog type");
				Test.Assert(container != null, "Expected Container type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(container);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected nested id-base ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves local file definition refs")]
	public static void T_ResolvesLocalFileDefinitionRef()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"common.schema.json#/definitions/Address\"}}}";
		let commonText = "{\"definitions\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected local file ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(schemas.Count == 2, scope $"Expected two generated types, got {schemas.Count}");
				let customer = FindSchema(schemas, "Customer");
				let address = FindSchema(schemas, "Address");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(address != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected local ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves external relative refs from external directory")]
	public static void T_ExternalRelativeRefsUseExternalDirectory()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String schemasDir = scope String();
		BuildOutputFilePath(tempDir, "schemas", schemasDir);
		Test.Assert(Directory.CreateDirectory(schemasDir) case .Ok, "Expected schemas directory");

		String sharedDir = scope String();
		BuildOutputFilePath(schemasDir, "shared", sharedDir);
		Test.Assert(Directory.CreateDirectory(sharedDir) case .Ok, "Expected shared directory");

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String orderPath = scope String();
		BuildOutputFilePath(schemasDir, "order.schema.json", orderPath);
		String addressPath = scope String();
		BuildOutputFilePath(sharedDir, "address.schema.json", addressPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"order\":{\"$ref\":\"schemas/order.schema.json#\"}}}";
		let orderText = "{\"title\":\"Order\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"./shared/address.schema.json#\"}}}";
		let addressText = "{\"title\":\"Address\",\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(orderPath, orderText) case .Ok, "Expected order fixture write");
		Test.Assert(File.WriteAllText(addressPath, addressText) case .Ok, "Expected address fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			String errorMessage = scope String("Expected nested local file refs to resolve");
			for (var err in resolver.Errors)
			{
				errorMessage.Append("\n");
				errorMessage.Append(err);
			}
			Test.Assert(resolveResult case .Ok, errorMessage);

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(FindSchema(schemas, "Customer") != null, "Expected Customer type");
				let order = FindSchema(schemas, "Order");
				Test.Assert(order != null, "Expected Order type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(order);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected external-relative ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves fragmentless external file refs")]
	public static void T_FragmentlessExternalFileRefResolvesRoot()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String addressPath = scope String();
		BuildOutputFilePath(tempDir, "address.schema.json", addressPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"address.schema.json\"}}}";
		let addressText = "{\"title\":\"Address\",\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(addressPath, addressText) case .Ok, "Expected address fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected fragmentless local file ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(schemas.Count == 2, scope $"Expected two generated types, got {schemas.Count}");
				let customer = FindSchema(schemas, "Customer");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected fragmentless ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves absolute external file refs")]
	public static void T_AbsoluteExternalFileRefResolves()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		String rootText = scope String("{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"");
		rootText.Append(commonPath);
		rootText.Append("#/$defs/Address\"}}}");
		let commonText = "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected absolute local file ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let customer = FindSchema(schemas, "Customer");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected absolute ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen resolves file URI external refs")]
	public static void T_FileUriExternalRefResolves()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		String rootText = scope String("{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"file://");
		rootText.Append(commonPath);
		rootText.Append("#/$defs/Address\"}}}");
		let commonText = "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected file URI local ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let customer = FindSchema(schemas, "Customer");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected file URI ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen normalizes dot-dot external ref paths")]
	public static void T_DotDotExternalRefPathResolves()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String nestedDir = scope String();
		BuildOutputFilePath(tempDir, "schemas", nestedDir);
		Test.Assert(Directory.CreateDirectory(nestedDir) case .Ok, "Expected nested schema directory");

		String rootPath = scope String();
		BuildOutputFilePath(nestedDir, "customer.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"../common.schema.json#/$defs/Address\"}}}";
		let commonText = "{\"$defs\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected dot-dot local file ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let customer = FindSchema(schemas, "Customer");
				Test.Assert(customer != null, "Expected Customer type");
				Test.Assert(FindSchema(schemas, "Address") != null, "Expected Address type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(customer);
				defer delete code;
				Test.Assert(code.Contains("public Address Address = new .() ~ delete _;"), scope $"Expected dot-dot ref field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen caches repeated external document refs")]
	public static void T_RepeatedExternalRefsShareDocument()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "order.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		let rootText = "{\"title\":\"Order\",\"type\":\"object\",\"properties\":{\"billing\":{\"$ref\":\"common.schema.json#/definitions/Address\"},\"shipping\":{\"$ref\":\"common.schema.json#/definitions/Address\"}}}";
		let commonText = "{\"definitions\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Order", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected repeated refs to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				Test.Assert(CountNamedSchemas(schemas, "Address") == 1, "Expected one generated Address model");
				let order = FindSchema(schemas, "Order");
				Test.Assert(order != null, "Expected Order type");

				let billingProp = order.FindProperty("billing");
				let shippingProp = order.FindProperty("shipping");
				Test.Assert(billingProp != null, "Expected billing property");
				Test.Assert(shippingProp != null, "Expected shipping property");
				Test.Assert(billingProp.Schema.ReferencedSchema == shippingProp.Schema.ReferencedSchema, "Expected repeated refs to share the same target schema");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen missing external file fails")]
	public static void T_MissingExternalFileFails()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "broken.schema.json", rootPath);
		let schemaText = "{\"title\":\"Broken\",\"type\":\"object\",\"properties\":{\"missing\":{\"$ref\":\"missing.schema.json#\"}}}";
		Test.Assert(File.WriteAllText(rootPath, schemaText) case .Ok, "Expected root fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Broken", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Err(.UnresolvedRef), "Expected missing external file to fail");
			Test.Assert(resolver.Errors.Count == 1, scope $"Expected one resolver error, got {resolver.Errors.Count}");
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen invalid external schema JSON fails")]
	public static void T_InvalidExternalSchemaJsonFails()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "broken.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "invalid.schema.json", commonPath);

		let schemaText = "{\"title\":\"Broken\",\"type\":\"object\",\"properties\":{\"missing\":{\"$ref\":\"invalid.schema.json#\"}}}";
		let invalidText = "{\"title\":\"Invalid\",\"type\":\"object\",\"properties\":";
		Test.Assert(File.WriteAllText(rootPath, schemaText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, invalidText) case .Ok, "Expected invalid external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Broken", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Err(.UnresolvedRef), "Expected invalid external JSON to fail");
			Test.Assert(resolver.Errors.Count == 1, scope $"Expected one resolver error, got {resolver.Errors.Count}");
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen missing external pointer fails")]
	public static void T_MissingExternalPointerFails()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "broken.schema.json", rootPath);
		String commonPath = scope String();
		BuildOutputFilePath(tempDir, "common.schema.json", commonPath);

		let schemaText = "{\"title\":\"Broken\",\"type\":\"object\",\"properties\":{\"missing\":{\"$ref\":\"common.schema.json#/definitions/Missing\"}}}";
		let commonText = "{\"definitions\":{\"Address\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(rootPath, schemaText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(commonPath, commonText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Broken", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Err(.UnresolvedRef), "Expected missing external pointer to fail");
			Test.Assert(resolver.Errors.Count == 1, scope $"Expected one resolver error, got {resolver.Errors.Count}");
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen external parser warnings surface and warnings-as-errors fails")]
	public static void T_ExternalParserWarningsAreCounted()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String rootPath = scope String();
		BuildOutputFilePath(tempDir, "customer.schema.json", rootPath);
		String addressPath = scope String();
		BuildOutputFilePath(tempDir, "address.schema.json", addressPath);

		let rootText = "{\"title\":\"Customer\",\"type\":\"object\",\"properties\":{\"address\":{\"$ref\":\"address.schema.json#\"}}}";
		let addressText = "{\"title\":\"Address\",\"type\":\"object\",\"additionalProperties\":false,\"properties\":{\"city\":{\"type\":\"string\",\"minLength\":1}}}";
		Test.Assert(File.WriteAllText(rootPath, rootText) case .Ok, "Expected root fixture write");
		Test.Assert(File.WriteAllText(addressPath, addressText) case .Ok, "Expected external fixture write");

		let parser = scope SchemaParser();
		let parseResult = parser.Parse(rootText, "Customer", rootPath);
		Test.Assert(parseResult case .Ok, "Expected schema to parse");
		Test.Assert(parser.Warnings.Count == 0, scope $"Expected root parser warnings to be empty, got {parser.Warnings.Count}");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected local file ref with external warnings to resolve");
			Test.Assert(resolver.Warnings.Count >= 2, scope $"Expected external parser warnings to surface, got {resolver.Warnings.Count}");

			if (resolveResult case .Ok(let schemas))
			{
				delete schemas;
			}

			resolver.Cleanup();
		}

		String strictOutputDir = scope String(rootPath);
		strictOutputDir.Append(".strict");
		CleanupDirectory(strictOutputDir);
		defer { CleanupDirectory(strictOutputDir); }

		String[] strictArgs = scope .(
			rootPath,
			"-n",
			"BJSON.SchemaCodeGen.Tests.Generated",
			"-o",
			strictOutputDir,
			"--warnings-as-errors"
		);
		let strictExitCode = Program.Main(strictArgs);
		Test.Assert(strictExitCode == 5, scope $"Expected warnings-as-errors to return 5, got {strictExitCode}");
		Test.Assert(!Directory.Exists(strictOutputDir), scope $"Strict generation should not create output directory: {strictOutputDir}");
	}

	[Test(Name = "SchemaCodeGen emits string additionalProperties extension data")]
	public static void T_EmitsStringAdditionalProperties()
	{
		let schemaText = "{\"title\":\"Settings\",\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\"}},\"additionalProperties\":{\"type\":\"string\"}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Settings");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");
		Test.Assert(parser.Warnings.Count == 0, scope $"Expected schema-valued additionalProperties to avoid warnings, got {parser.Warnings.Count}");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected schema to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let settings = FindSchema(schemas, "Settings");
				Test.Assert(settings != null, "Expected Settings type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(settings);
				defer delete code;

				Test.Assert(code.Contains("public int64 Id;"), scope $"Expected declared property field. Code:\n{code}");
				Test.Assert(code.Contains("[JsonExtensionData]\n\tpublic Dictionary<String, String> AdditionalProperties = new .() ~ DeleteDictionaryAndKeysAndValues!(_);"), scope $"Expected string extension data field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen emits ref additionalProperties extension data")]
	public static void T_EmitsRefAdditionalProperties()
	{
		let schemaText = "{\"title\":\"Labels\",\"type\":\"object\",\"additionalProperties\":{\"$ref\":\"#/$defs/Label\"},\"$defs\":{\"Label\":{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}}}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Labels");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected additionalProperties ref to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let labels = FindSchema(schemas, "Labels");
				Test.Assert(labels != null, "Expected Labels type");
				Test.Assert(FindSchema(schemas, "Label") != null, "Expected referenced Label type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(labels);
				defer delete code;

				Test.Assert(code.Contains("[JsonExtensionData]\n\tpublic Dictionary<String, Label> AdditionalProperties = new .() ~ DeleteDictionaryAndKeysAndValues!(_);"), scope $"Expected ref extension data field. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen disambiguates additionalProperties field name")]
	public static void T_AdditionalPropertiesFieldNameCollision()
	{
		let schemaText = "{\"title\":\"Settings\",\"type\":\"object\",\"properties\":{\"additionalProperties\":{\"type\":\"integer\"}},\"additionalProperties\":{\"type\":\"string\"}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "Settings");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "Expected schema to resolve");

			if (resolveResult case .Ok(let schemas))
			{
				let settings = FindSchema(schemas, "Settings");
				Test.Assert(settings != null, "Expected Settings type");

				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(settings);
				defer delete code;

				Test.Assert(code.Contains("public int64 AdditionalProperties;"), scope $"Expected declared property to keep its natural field name. Code:\n{code}");
				Test.Assert(code.Contains("public Dictionary<String, String> AdditionalProperties2"), scope $"Expected extension data field to be suffixed. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen bool additionalProperties behavior")]
	public static void T_BoolAdditionalPropertiesBehavior()
	{
		let trueSchemaText = "{\"title\":\"OpenModel\",\"type\":\"object\",\"additionalProperties\":true}";
		let trueParser = scope SchemaParser();
		let trueParseResult = trueParser.Parse(trueSchemaText, "OpenModel");
		Test.Assert(trueParseResult case .Ok, "Expected true additionalProperties schema to parse");
		Test.Assert(trueParser.Warnings.Count == 0, scope $"additionalProperties:true should not warn, got {trueParser.Warnings.Count}");
		if (trueParseResult case .Ok(let trueSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(trueSchema);
			Test.Assert(resolveResult case .Ok, "Expected true additionalProperties schema to resolve");
			if (resolveResult case .Ok(let schemas))
			{
				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(schemas[0]);
				defer delete code;
				Test.Assert(!code.Contains("[JsonExtensionData]"), scope $"additionalProperties:true should not generate extension data. Code:\n{code}");
				delete schemas;
			}
			resolver.Cleanup();
		}

		let falseSchemaText = "{\"title\":\"ClosedModel\",\"type\":\"object\",\"additionalProperties\":false}";
		let falseParser = scope SchemaParser();
		let falseParseResult = falseParser.Parse(falseSchemaText, "ClosedModel");
		Test.Assert(falseParseResult case .Ok, "Expected false additionalProperties schema to parse");
		Test.Assert(falseParser.Warnings.Count == 1, scope $"additionalProperties:false should warn once, got {falseParser.Warnings.Count}");
		if (falseParseResult case .Ok(let falseSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(falseSchema);
			Test.Assert(resolveResult case .Ok, "Expected false additionalProperties schema to resolve");
			if (resolveResult case .Ok(let schemas))
			{
				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(schemas[0]);
				defer delete code;
				Test.Assert(!code.Contains("[JsonExtensionData]"), scope $"additionalProperties:false should not generate extension data. Code:\n{code}");
				delete schemas;
			}
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen warns but emits structural model")]
	public static void T_WarningsDoNotFail()
	{
		let schemaText = "{\"title\":\"WarningSample\",\"type\":\"object\",\"additionalProperties\":false,\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":2},\"external\":{\"$ref\":\"https://example.com/external.schema.json#/Thing\"}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "WarningSample");
		Test.Assert(parseResult case .Ok, "Expected schema to parse with warnings");
		Test.Assert(parser.Warnings.Count >= 2, scope $"Expected parser warnings, got {parser.Warnings.Count}");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Ok, "External refs should warn and fall back");
			Test.Assert(resolver.Warnings.Count == 1, scope $"Expected one resolver warning, got {resolver.Warnings.Count}");

			if (resolveResult case .Ok(let schemas))
			{
				GeneratorConfig config = .();
				config.Namespace = scope String("BJSON.SchemaCodeGen.Tests.Generated");

				let generator = scope CodeGenerator(config);
				let code = generator.Generate(schemas[0]);
				defer delete code;

				Test.Assert(code.Contains("public JsonValue External;"), scope $"External ref should fall back to JsonValue. Code:\n{code}");

				delete schemas;
			}

			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen warnings-as-errors blocks output")]
	public static void T_WarningsAsErrorsBlocksOutput()
	{
		let schemaText = "{\"title\":\"WarningSample\",\"type\":\"object\",\"additionalProperties\":false,\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":2},\"score\":{\"type\":\"integer\",\"minimum\":0}}}";
		String schemaPath = scope String();
		let tempResult = Path.GetTempFileName(schemaPath);
		Test.Assert(tempResult case .Ok, "Expected temp schema path");
		defer { File.Delete(schemaPath).IgnoreError(); }

		let writeSchemaResult = File.WriteAllText(schemaPath, schemaText);
		Test.Assert(writeSchemaResult case .Ok, "Expected schema fixture to be written");

		String defaultOutputDir = scope String(schemaPath);
		defaultOutputDir.Append(".default");
		String strictOutputDir = scope String(schemaPath);
		strictOutputDir.Append(".strict");
		CleanupDirectory(defaultOutputDir);
		CleanupDirectory(strictOutputDir);
		defer { CleanupDirectory(defaultOutputDir); }
		defer { CleanupDirectory(strictOutputDir); }

		String[] defaultArgs = scope .(
			schemaPath,
			"-n",
			"BJSON.SchemaCodeGen.Tests.Generated",
			"-o",
			defaultOutputDir
		);
		let defaultExitCode = Program.Main(defaultArgs);
		Test.Assert(defaultExitCode == 0, scope $"Expected default generation to return 0, got {defaultExitCode}");

		String defaultGeneratedFile = scope String();
		BuildOutputFilePath(defaultOutputDir, "WarningSample.bf", defaultGeneratedFile);
		Test.Assert(File.Exists(defaultGeneratedFile), scope $"Expected generated file: {defaultGeneratedFile}");

		String[] strictArgs = scope .(
			schemaPath,
			"-n",
			"BJSON.SchemaCodeGen.Tests.Generated",
			"-o",
			strictOutputDir,
			"--warnings-as-errors"
		);
		let strictExitCode = Program.Main(strictArgs);
		Test.Assert(strictExitCode == 5, scope $"Expected warnings-as-errors to return 5, got {strictExitCode}");
		Test.Assert(!Directory.Exists(strictOutputDir), scope $"Strict generation should not create output directory: {strictOutputDir}");
	}

	[Test(Name = "SchemaCodeGen unresolved internal ref fails")]
	public static void T_UnresolvedInternalRefFails()
	{
		let schemaText = "{\"title\":\"BrokenRef\",\"type\":\"object\",\"properties\":{\"missing\":{\"$ref\":\"#/$defs/Missing\"}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "BrokenRef");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Err(.UnresolvedRef), "Expected unresolved internal ref to fail");
			Test.Assert(resolver.Errors.Count == 1, scope $"Expected one resolver error, got {resolver.Errors.Count}");
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen unresolved anchor ref fails")]
	public static void T_UnresolvedAnchorRefFails()
	{
		let schemaText = "{\"title\":\"BrokenAnchor\",\"type\":\"object\",\"properties\":{\"missing\":{\"$ref\":\"#missingAnchor\"}}}";
		let parser = scope SchemaParser();
		let parseResult = parser.Parse(schemaText, "BrokenAnchor");
		Test.Assert(parseResult case .Ok, "Expected schema to parse");

		if (parseResult case .Ok(let rootSchema))
		{
			let resolver = scope TypeResolver();
			let resolveResult = resolver.Resolve(rootSchema);
			Test.Assert(resolveResult case .Err(.UnresolvedRef), "Expected unresolved anchor ref to fail");
			Test.Assert(resolver.Errors.Count == 1, scope $"Expected one resolver error, got {resolver.Errors.Count}");
			resolver.Cleanup();
		}
	}

	[Test(Name = "SchemaCodeGen -c outranks the schema title")]
	public static void T_RootClassNameOutranksTitle()
	{
		String tempDir = scope String();
		CreateTempDirectory(tempDir);
		defer { CleanupDirectory(tempDir); }

		String schemaPath = scope String();
		BuildOutputFilePath(tempDir, "payload.schema.json", schemaPath);
		let schemaText = "{\"title\":\"TitleSample\",\"type\":\"object\",\"properties\":{\"detail\":{\"type\":\"object\",\"properties\":{\"city\":{\"type\":\"string\"}}}}}";
		Test.Assert(File.WriteAllText(schemaPath, schemaText) case .Ok, "Expected schema fixture write");

		String overrideDir = scope String();
		BuildOutputFilePath(tempDir, "override", overrideDir);
		String[] overrideArgs = scope .(
			schemaPath,
			"-n",
			"BJSON.SchemaCodeGen.Tests.Generated",
			"-o",
			overrideDir,
			"-c",
			"OverrideSample"
		);
		let overrideExitCode = Program.Main(overrideArgs);
		Test.Assert(overrideExitCode == 0, scope $"Expected -c generation to return 0, got {overrideExitCode}");

		String overrideRootFile = scope String();
		BuildOutputFilePath(overrideDir, "OverrideSample.bf", overrideRootFile);
		Test.Assert(File.Exists(overrideRootFile), scope $"Expected -c root file: {overrideRootFile}");

		String overrideNestedFile = scope String();
		BuildOutputFilePath(overrideDir, "OverrideSampleDetail.bf", overrideNestedFile);
		Test.Assert(File.Exists(overrideNestedFile), scope $"Expected nested type named from the -c root: {overrideNestedFile}");

		String titleFileUnderOverride = scope String();
		BuildOutputFilePath(overrideDir, "TitleSample.bf", titleFileUnderOverride);
		Test.Assert(!File.Exists(titleFileUnderOverride), scope $"Title must not outrank -c: {titleFileUnderOverride}");

		String titleDir = scope String();
		BuildOutputFilePath(tempDir, "title", titleDir);
		String[] titleArgs = scope .(
			schemaPath,
			"-n",
			"BJSON.SchemaCodeGen.Tests.Generated",
			"-o",
			titleDir
		);
		let titleExitCode = Program.Main(titleArgs);
		Test.Assert(titleExitCode == 0, scope $"Expected title-named generation to return 0, got {titleExitCode}");

		String titleRootFile = scope String();
		BuildOutputFilePath(titleDir, "TitleSample.bf", titleRootFile);
		Test.Assert(File.Exists(titleRootFile), scope $"Expected title root file: {titleRootFile}");

		String titleNestedFile = scope String();
		BuildOutputFilePath(titleDir, "TitleSampleDetail.bf", titleNestedFile);
		Test.Assert(File.Exists(titleNestedFile), scope $"Expected nested type named from the title root: {titleNestedFile}");
	}

	[Test(Name = "SchemaCodeGen usage states -c outranks title")]
	public static void T_UsageStatesRootClassPrecedence()
	{
		String usage = scope String();
		Program.AppendUsage(usage);

		Test.Assert(usage.Contains("-c, --class <name>      Root class name; outranks the schema title"), scope $"Expected -c precedence in usage. Usage:\n{usage}");
	}

	private static void CleanupDirectory(StringView path)
	{
		if (Directory.Exists(path))
		{
			Directory.DelTree(path).IgnoreError();
		}
	}

	private static void CreateTempDirectory(String output)
	{
		String tempFile = scope String();
		let tempResult = Path.GetTempFileName(tempFile);
		Test.Assert(tempResult case .Ok, "Expected temp path");
		File.Delete(tempFile).IgnoreError();

		output.Set(tempFile);
		output.Append(".dir");
		CleanupDirectory(output);
		Test.Assert(Directory.CreateDirectory(output) case .Ok, scope $"Expected temp directory: {output}");
	}

	private static SchemaModel FindSchema(List<SchemaModel> schemas, StringView name)
	{
		for (var schema in schemas)
		{
			if (schema.Name == name)
			{
				return schema;
			}
		}

		return null;
	}

	private static int CountNamedSchemas(List<SchemaModel> schemas, StringView name)
	{
		int count = 0;
		for (var schema in schemas)
		{
			if (schema.Name == name)
			{
				count++;
			}
		}

		return count;
	}

	private static void BuildOutputFilePath(StringView outputDir, StringView fileName, String outPath)
	{
		outPath.Append(outputDir);
		if (!outputDir.EndsWith("\\") && !outputDir.EndsWith("/"))
		{
			outPath.Append(Path.DirectorySeparatorChar);
		}
		outPath.Append(fileName);
	}
}
