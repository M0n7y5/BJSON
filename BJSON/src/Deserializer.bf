using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;
using System.Collections;
namespace BJSON
{
	/// Builds a JsonValue tree from JSON text: the IHandler that JsonReader drives while parsing.
	/// A returned tree belongs to the caller, and the instance drops its parse state on every exit
	/// path, so one Deserializer can parse any number of documents.
	/// A handler callback returns false when the event cannot be applied to the tree, which makes
	/// the reader abort with a parse error.
	public class Deserializer : IHandler
	{
		Queue<JsonValue> mTreeStack = new .(32) ~ delete _;

		String mCurrentKey = null;
		// Keys are copied into this arena because the reader passes a view of a scope buffer that
		// dies before the matching value arrives. The arena is released with the deserializer, not
		// per document, so keys from earlier parses stay resident until then.
		BumpAllocator keyAlloc = new .() ~ delete _;

		bool mIsIgnoringDuplicate = false;
		int mIgnoredDepthCounter = 0;

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
			let reader = scope JsonReader(this, Config);

			let result = reader.Parse(scope StringStream(jsonText, .Reference));

			return FinishParse(result);
		}

		/// Deserializes JSON from a stream into a JsonValue tree.
		/// @param stream The stream containing JSON data.
		/// @returns The parsed JsonValue, owned by the caller and needing Dispose, or a JsonParsingError.
		public Result<JsonValue, JsonParsingError> Deserialize(Stream stream)
		{
			let reader = scope JsonReader(this, Config);

			let result = reader.Parse(stream);

			return FinishParse(result);
		}

		/// Turns a finished parse into the document root and drops the parse state either way.
		/// A successful root leaves with the caller; a failed parse disposes the partial tree here.
		/// @param parseResult The result JsonReader.Parse reported for this document.
		/// @returns The document root, InvalidDocument when the parse built nothing, or the parse error.
		private Result<JsonValue, JsonParsingError> FinishParse(Result<void, JsonParsingError> parseResult)
		{
			switch (parseResult)
			{
				case .Ok:
					{
						if (mTreeStack.Count == 0)
						{
							return .Err(.InvalidDocument);
						}

						let root = mTreeStack.Front;
						ResetParseState();

						return root;
					}
				case .Err(let err):
					if (mTreeStack.Count != 0)
						mTreeStack.Front.Dispose();

					ResetParseState();

					return .Err(err);
			}
		}

		/// Drops the parse state so the instance can parse another document.
		/// The returned tree is owned by the caller, so the queue is cleared without disposing.
		private void ResetParseState()
		{
			mTreeStack.Clear();
			mCurrentKey = null;
			mIsIgnoringDuplicate = false;
			mIgnoredDepthCounter = 0;
		}

		[Inline]
		private bool AddValue(JsonValue value)
		{
			if (mTreeStack.Count == 0)
			{
				mTreeStack.Add(value);
				return true;
			}

			var document = ref mTreeStack.Back;

			if (mIsIgnoringDuplicate)
			{
				value.Dispose();
				return true;
			}

			switch (document.type)
			{
				case .OBJECT:
					if (mCurrentKey == null)
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
			if (jObj.data.object.ContainsKeyAlt(mCurrentKey))
			{
				switch (Config.DuplicateBehavior)
				{
					case .ThrowError:
						value.Dispose();
						mCurrentKey = null;
						return false;

					case .Ignore:
						value.Dispose();
						mCurrentKey = null;
						return true;

					case .AlwaysRewrite:
						jObj[mCurrentKey] = value;
						mCurrentKey = null;
						return true;
				}
			}
			else
			{
				jObj.Add(mCurrentKey, value);
				mCurrentKey = null;
				return true;
			}
		}

		/// Opens a container, either as the document root or under the pending key. A duplicate key
		/// follows Config.DuplicateBehavior; `.Ignore` drops every event up to the matching end.
		/// @param container A fresh JsonObject or JsonArray. Like AddValue, this disposes it on
		/// every path that does not hand it to the tree.
		/// @returns False when the container cannot be opened, which aborts the parse.
		private bool StartContainer(JsonValue container)
		{
			if (mIsIgnoringDuplicate)
			{
				container.Dispose();
				mIgnoredDepthCounter++;
				return true;
			}

			if (mTreeStack.Count == 0)
			{
				if (mCurrentKey != null)
				{
					container.Dispose();
					return false;
				}

				mTreeStack.Add(container);
				return true;
			}

			var document = ref mTreeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (mCurrentKey == null)
					{
						container.Dispose();
						return false;
					}

					let jObj = document.As<JsonObject>();

					if (jObj.data.object.ContainsKeyAlt(mCurrentKey))
					{
						switch (Config.DuplicateBehavior)
						{
							case .ThrowError:
								container.Dispose();
								return false;

							case .Ignore:
								container.Dispose();
								mIsIgnoringDuplicate = true;
								mCurrentKey = null;
								return true;

							// The indexer disposes the value it replaces, so the old one is not
							// disposed here.
							case .AlwaysRewrite:
								jObj[mCurrentKey] = container;
								mTreeStack.Add(container);
								mCurrentKey = null;
								return true;
						}
					}

					jObj.Add(mCurrentKey, container);
					mTreeStack.Add(container);
					mCurrentKey = null;
					return true;

				case .ARRAY:
					document.As<JsonArray>().Add(container);
					mTreeStack.Add(container);
					return true;

				default:
					container.Dispose();
					return false;
			}
		}

		/// Closes the open container, leaving the root on the stack for Deserialize to return.
		/// While a duplicate is being ignored this only unwinds the ignored nesting.
		/// @param expected The type of the container the closing token belongs to.
		/// @returns False when no container is open, or when the closed one is of another type.
		private bool EndContainer(JsonType expected)
		{
			if (mIsIgnoringDuplicate)
			{
				if (mIgnoredDepthCounter == 0)
				{
					mIsIgnoringDuplicate = false;
					return true;
				}

				mIgnoredDepthCounter--;
				return true;
			}

			if (mTreeStack.Count == 0)
				return false;

			if (mTreeStack.Count == 1)
				return true;

			if (mTreeStack.TryPopBack() case .Ok(let val))
			{
				if (val.type != expected)
					return false;
			}

			return true;
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

		/// Opens an object, either as the document root or under the pending key.
		public bool StartObject()
		{
			return StartContainer(JsonObject());
		}

		/// Records the key that the next value is stored under. `copy` is ignored: the key is
		/// always copied into the instance's arena, which outlives the reader's view of it.
		[Inline]
		public bool Key(StringView str, bool copy)
		{
			mCurrentKey = new:keyAlloc String(str);

			return true;
		}

		/// Closes the open object. The root container stays on the stack for Deserialize to return.
		public bool EndObject()
		{
			return EndContainer(.OBJECT);
		}

		/// Opens an array, with the same duplicate-key handling as StartObject.
		public bool StartArray()
		{
			return StartContainer(JsonArray());
		}

		/// Closes the open array. The root container stays on the stack for Deserialize to return.
		public bool EndArray()
		{
			return EndContainer(.ARRAY);
		}
	}
}
