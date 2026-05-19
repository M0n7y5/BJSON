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
	
	[Test(Name = "SchemaCodeGen warns but emits structural model")]
	public static void T_WarningsDoNotFail()
	{
		let schemaText = "{\"title\":\"WarningSample\",\"type\":\"object\",\"additionalProperties\":false,\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":2},\"external\":{\"$ref\":\"external.schema.json#/Thing\"}}}";
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

	private static void CleanupDirectory(StringView path)
	{
		if (Directory.Exists(path))
		{
			Directory.DelTree(path).IgnoreError();
		}
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
