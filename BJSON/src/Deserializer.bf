using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;
using System.Collections;
namespace BJSON
{
	/// Specifies how duplicate keys in JSON objects should be handled during parsing.
	public enum DuplicateKeyBehavior
	{
		/// Return error if duplicate key is found.
		/// NOTE: RFC 8259 only says names SHOULD be unique, so this rejects documents that other
		/// parsers accept.
		ThrowError,
		/// Skip the duplicate and keep the first occurrence.
		Ignore,
		/// Overwrite the previous value with the duplicate key's value.
		AlwaysRewrite
	}

	/// Configuration options for JSON deserialization.
	public struct DeserializerConfig
	{
		/// Whether `//` line comments and `/* */` block comments are skipped like whitespace.
		/// NOTE: Comments are not part of RFC 8259, so such documents are not portable.
		public bool EnableComments = false;

		/// Behavior when an object repeats a key that is already present.
		public DuplicateKeyBehavior DuplicateBehavior = .AlwaysRewrite;
	}

	/// Builds a JsonValue tree from JSON text: the IHandler that JsonReader drives while parsing.
	/// A returned tree belongs to the caller, and the instance drops its parse state on every exit
	/// path, so one Deserializer can parse any number of documents.
	/// A handler callback returns false when the event cannot be applied to the tree, which makes
	/// the reader abort with a parse error.
	public class Deserializer : IHandler
	{
		Queue<JsonValue> treeStack = new .(32) ~ delete _;

		String currentKey = null;
		// Keys are copied into this arena because the reader passes a view of a scope buffer that
		// dies before the matching value arrives. The arena is released with the deserializer, not
		// per document, so keys from earlier parses stay resident until then.
		BumpAllocator keyAlloc = new .() ~ delete _;

		bool IsIgnoringDuplicate = false;
		int IgnoredDepthCounter = 0;

		/// Parsing options. JsonReader copies these when Deserialize constructs it, so a change
		/// made during a parse does not affect the parse in flight.
		public DeserializerConfig Config = .();

		/// Creates a new Deserializer with default configuration.
		public this() { }

		/// Creates a new Deserializer with the specified configuration.
		/// @param config The deserialization configuration options.
		public this(DeserializerConfig config)
		{
			this.Config = config;
		}

		/// Deserializes a JSON string into a JsonValue tree.
		/// @param jsonText The JSON string to parse.
		/// @returns The parsed JsonValue, owned by the caller and needing Dispose, or a JsonParsingError.
		public Result<JsonValue, JsonParsingError> Deserialize(StringView jsonText)
		{
			let reader = scope JsonReader(this);

			let result = reader.Parse(scope StringStream(jsonText, .Reference));

			switch (result)
			{
				case .Ok:
					{
						if (this.treeStack.Count == 0)
						{
							return .Err(.InvalidDocument);
						}

						let root = this.treeStack.Front;
						ResetParseState();

						return root;
					}
				case .Err(let err):
					if (this.treeStack.Count != 0)
						this.treeStack.Front.Dispose();

					ResetParseState();

					return .Err(err);
			}
		}

		/// Deserializes JSON from a stream into a JsonValue tree.
		/// @param stream The stream containing JSON data.
		/// @returns The parsed JsonValue, owned by the caller and needing Dispose, or a JsonParsingError.
		public Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			let reader = scope JsonReader(this);

			let result = reader.Parse(stream);

			switch (result)
			{
				case .Ok:
					{
						if (this.treeStack.Count == 0)
						{
							return .Err(.InvalidDocument);
						}

						let root = this.treeStack.Front;
						ResetParseState();

						return root;
					}
				case .Err(let err):
					if (this.treeStack.Count != 0)
						this.treeStack.Front.Dispose();

					ResetParseState();

					return .Err(err);
			}
		}

		/// Drops the parse state so the instance can parse another document.
		/// The returned tree is owned by the caller, so the queue is cleared without disposing.
		private void ResetParseState()
		{
			treeStack.Clear();
			currentKey = null;
			IsIgnoringDuplicate = false;
			IgnoredDepthCounter = 0;
		}

		[Inline]
		private bool AddValue(JsonValue value)
		{
			if (treeStack.Count == 0)
			{
				treeStack.Add(value);
				return true;
			}

			var document = ref treeStack.Back;

			if (IsIgnoringDuplicate)
			{
				value.Dispose();
				return true;
			}

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
					{
						value.Dispose();
						return false;
					}

					return AddToObject(document.As<JsonObject>(), value);

				case .ARRAY:
					document.As<JsonArray>().Add(value);
					return true;

				default:
					value.Dispose();
					return false;
			}
		}

		[Inline]
		private bool AddToObject(JsonObject jObj, JsonValue value)
		{
			if (jObj.data.object.ContainsKeyAlt(currentKey))
			{
				switch (Config.DuplicateBehavior)
				{
					case .ThrowError:
						value.Dispose();
						currentKey = null;
						return false;

					case .Ignore:
						value.Dispose();
						currentKey = null;
						return true;

					case .AlwaysRewrite:
						jObj[currentKey] = value;
						currentKey = null;
						return true;
				}
			}
			else
			{
				jObj.Add(currentKey, value);
				currentKey = null;
				return true;
			}
		}

		/// Adds a JSON null to the open container, or as the document root.
		[Inline]
		public bool Null()
		{
			return AddValue(JsonNull());
		}

		/// Adds a boolean to the open container, or as the document root.
		[Inline]
		public bool Bool(bool value)
		{
			return AddValue(JsonBool(value));
		}

		/// Adds a double. The reader picks this overload for numbers with a fraction or exponent,
		/// for magnitudes past the 64-bit integer range, and for a bare -0, whose sign only a
		/// double can carry.
		[Inline]
		public bool Number(double value)
		{
			return AddValue(JsonNumber(value));
		}

		/// Adds an unsigned integer. The reader picks this overload above int64.MaxValue.
		[Inline]
		public bool Number(uint64 value)
		{
			return AddValue(JsonNumber(value));
		}
		
		/// Adds a signed integer. The reader picks this overload for values that fit int64,
		/// int64.MinValue included.
		[Inline]
		public bool Number(int64 value)
		{
			return AddValue(JsonNumber(value));
		}

		/// Adds a string. `copy` is ignored: JsonString always copies the text, so the reader's
		/// scratch buffer is never aliased.
		[Inline]
		public bool String(StringView value, bool copy)
		{
			return AddValue(JsonString(value));
		}

		/// Opens an object, either as the document root or under the pending key. A duplicate key
		/// follows Config.DuplicateBehavior; `.Ignore` drops every event up to the matching end.
		public bool StartObject()
		{
			if (IsIgnoringDuplicate)
			{
				IgnoredDepthCounter++;
				return true;
			}

			if (treeStack.Count == 0)
			{
				if (currentKey != null)
					return false;

				treeStack.Add(JsonObject());
				return true;
			}
			else
			{
				var document = ref treeStack.Back;

				switch (document.type)
				{
					case .OBJECT:
						if (currentKey == null)
							return false;

						let jObj = document.As<JsonObject>();

						if (jObj.data.object.ContainsKeyAlt(currentKey))
						{
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									return false;

								case .Ignore:
									IsIgnoringDuplicate = true;
									currentKey = null;
									return true;

								case .AlwaysRewrite:
									let jVal = JsonObject();
									jObj[currentKey] = jVal;
									treeStack.Add(jVal);
									currentKey = null;
									return true;
							}
						}
						else
						{
							let jVal = JsonObject();
							jObj.Add(currentKey, jVal);
							treeStack.Add(jVal);
							currentKey = null;
							return true;
						}

					case .ARRAY:
						let jVal = JsonObject();
						document.As<JsonArray>().Add(jVal);
						treeStack.Add(jVal);
						return true;
					default:
						return false;
				}
			}
		}

		/// Records the key that the next value is stored under. `copy` is ignored: the key is
		/// always copied into the instance's arena, which outlives the reader's view of it.
		[Inline]
		public bool Key(StringView str, bool copy)
		{
			currentKey = new:keyAlloc String(str);

			return true;
		}

		/// Closes the open object. The root container stays on the stack for Deserialize to return.
		public bool EndObject()
		{
			if (IsIgnoringDuplicate)
			{
				if (IgnoredDepthCounter == 0)
				{
					IsIgnoringDuplicate = false;
					return true;
				}

				IgnoredDepthCounter--;
				return true;
			}

			if (treeStack.Count == 0)
				return false;

			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				if (val.type != .OBJECT)
					return false;
			}

			return true;
		}

		/// Opens an array, with the same duplicate-key handling as StartObject.
		public bool StartArray()
		{
			if (IsIgnoringDuplicate)
			{
				IgnoredDepthCounter++;
				return true;
			}

			if (treeStack.Count == 0)
			{
				if (currentKey != null)
					return false;

				treeStack.Add(JsonArray());
				return true;
			}
			else
			{
				var document = ref treeStack.Back;

				switch (document.type)
				{
					case .OBJECT:
						if (currentKey == null)
							return false;

						let jObj = document.As<JsonObject>();

						if (jObj.data.object.ContainsKeyAlt(currentKey))
						{
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									return false;

								case .Ignore:
									IsIgnoringDuplicate = true;
									currentKey = null;
									return true;

								case .AlwaysRewrite:
									let jVal = JsonArray();
									jObj[currentKey] = jVal;
									treeStack.Add(jVal);
									currentKey = null;
									return true;
							}
						}
						else
						{
							let jVal = JsonArray();
							jObj.Add(currentKey, jVal);
							treeStack.Add(jVal);
							currentKey = null;
							return true;
						}

					case .ARRAY:
						let jVal = JsonArray();
						document.As<JsonArray>().Add(jVal);

						treeStack.Add(jVal);

						return true;
					default:
						return false;
				}
			}
		}

		/// Closes the open array. The root container stays on the stack for Deserialize to return.
		public bool EndArray()
		{
			if (IsIgnoringDuplicate)
			{
				if (IgnoredDepthCounter == 0)
				{
					IsIgnoringDuplicate = false;
					return true;
				}

				IgnoredDepthCounter--;
				return true;
			}

			if (treeStack.Count == 0)
				return false;

			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				if (val.type != .ARRAY)
					return false;
			}

			return true;
		}
	}
}
