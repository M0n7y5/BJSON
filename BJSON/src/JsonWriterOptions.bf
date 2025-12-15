using System;

namespace BJSON
{
	public struct JsonWriterOptions
	{
		/// Whether to format the output with indentation and newlines
		public bool Indented = false;

		/// The string used for indentation (e.g., "  " for 2 spaces, "\t" for tabs)
		public StringView IndentString = "  ";

		/// The string used for newlines
		public StringView NewLine = "\n";
	}
}
