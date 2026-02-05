using System;
using System.IO;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class FileWriter
{
	public Result<void, FileWriteError> WriteFiles(List<SchemaModel> schemas, GeneratorConfig config, StringView outputDir)
	{
		var generator = scope CodeGenerator(config);
		
		for (var schema in schemas)
		{
			if (schema.Type != .Object && schema.Type != .Enum)
			{
				continue;
			}
			
			String filePath = scope String();
			filePath.Append(outputDir);
			if (!outputDir.EndsWith("\\") && !outputDir.EndsWith("/"))
			{
				filePath.Append(Path.DirectorySeparatorChar);
			}
			
			// Sanitize filename - only allow alphanumeric characters
			for (int i = 0; i < schema.Name.Length; i++)
			{
				char8 c = schema.Name[i];
				if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
				{
					filePath.Append(c);
				}
			}
			filePath.Append(".bf");
			
			var code = generator.Generate(schema);
			defer delete code;
			
			var dir = scope String();
			Path.GetDirectoryPath(filePath, dir);
			
			if (!dir.IsEmpty && !Directory.Exists(dir))
			{
				var createResult = Directory.CreateDirectory(dir);
				if (createResult case .Err(let err))
				{
					return .Err(.CreateDirectoryFailed(scope $"Failed to create directory: {err}"));
				}
			}
			
			var writeResult = File.WriteAllText(filePath, code, .UTF8);
			if (writeResult case .Err(let err))
			{
				return .Err(.WriteFailed(scope $"Failed to write file: {err}"));
			}
			
			Console.WriteLine(scope $"Generated: {filePath}");
		}
		
		return .Ok;
	}
}

enum FileWriteError
{
	case CreateDirectoryFailed(String);
	case WriteFailed(String);
}
