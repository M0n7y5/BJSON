using System;
using System.IO;
using System.Collections;

namespace BJSON.SchemaCodeGen;

class FileWriter
{
	/// Writes one Beef file per generated type into outputDir, creating the directory when it is
	/// missing.
	/// @param schemas The types to generate.
	/// @param config Generator options.
	/// @param outputDir Directory that receives the files.
	/// @returns .Ok once every file is on disk, otherwise the failure and how far the run got.
	public Result<void, GeneratedFileError> WriteFiles(List<SchemaModel> schemas, GeneratorConfig config, StringView outputDir)
	{
		var generator = scope CodeGenerator(config);
		int filesWritten = 0;

		if (!outputDir.IsEmpty && !Directory.Exists(outputDir))
		{
			if (Directory.CreateDirectory(outputDir) case .Err(let err))
			{
				return .Err(.CreateDirectoryFailed(err));
			}
		}

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

			// Sanitize filename - only allow the characters a type name can hold
			for (int i = 0; i < schema.Name.Length; i++)
			{
				char8 c = schema.Name[i];
				if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_')
				{
					filePath.Append(c);
				}
			}
			filePath.Append(".bf");

			var code = generator.Generate(schema);
			defer delete code;

			// File.WriteAllText with an Encoding discards the result of the underlying write, so a
			// short write reads as success. The two argument overload reports it, and a Beef String
			// already holds UTF-8.
			if (File.WriteAllText(filePath, code) case .Err)
			{
				return .Err(.WriteFailed(filesWritten, schemas.Count));
			}

			filesWritten++;
			Console.WriteLine(scope $"Generated: {filePath}");
		}

		return .Ok;
	}
}

/// Why writing the generated files failed.
/// Payloads carry copyable values only: an error outlives the call that produced it, so a `scope`
/// string payload would dangle by the time the caller formats it.
enum GeneratedFileError
{
	/// The output directory was missing and could not be created.
	case CreateDirectoryFailed(Platform.BfpFileResult result);
	/// A file could not be written. Payloads count the files already on disk and the files the run
	/// owed, so the caller can report the output directory as incomplete.
	case WriteFailed(int filesWritten, int fileCount);

	public override void ToString(String string)
	{
		switch (this)
		{
		case CreateDirectoryFailed(let result):
			string.AppendF("the output directory could not be created ({})", result);
		case WriteFailed(let filesWritten, let fileCount):
			string.AppendF("only {} of {} files were written, so the output is incomplete", filesWritten, fileCount);
		}
	}
}
