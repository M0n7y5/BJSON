using System;

namespace BJSON
{
	/// Output formatting options, used by JsonWriter and by the serializers comptime emits.
	/// IndentString and NewLine are stored as views, not copies, so the text they point at
	/// must outlive every write that uses these options.
	public struct JsonWriterOptions
	{
		/// Whether to format the output with indentation and newlines.
		public bool Indented = false;

		/// The string used for one indentation level (e.g., "  " for 2 spaces, "\t" for tabs).
		public StringView IndentString = "  ";

		/// The string used for newlines.
		public StringView NewLine = "\n";
	}
}
