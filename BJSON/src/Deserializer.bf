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
		/// NOTE: This option is not RFC 8259 compliant.
		ThrowError,
		/// Skip the duplicate and keep the first occurrence.
		Ignore,
		/// Overwrite the previous value with the duplicate key's value.
		AlwaysRewrite
	}

	/// Configuration options for JSON deserialization.
	public struct DeserializerConfig
	{
		/// Enable support for comments in JSON string.
		/// This enables support for trailing and inline comments.
		public bool EnableComments = false;

		/// Choose behavior if multiple objects with the same key
		/// are found during parsing.
		public DuplicateKeyBehavior DuplicateBehavior = .AlwaysRewrite;
	}

	/// Parses JSON text into a JsonValue tree structure.
	/// Handles objects, arrays, strings, numbers, booleans, and null values.
	public class Deserializer : IHandler
	{
		// this will gonna contain only container types
		Queue<JsonValue> treeStack = new .(32) ~ delete _;

		String currentKey = null;
		BumpAllocator keyAlloc = new .() ~ delete _;

		bool IsIgnoringDuplicate = false;
		int IgnoredDepthCounter = 0;

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
		/// @returns The parsed JsonValue or a JsonParsingError on failure.
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

						return this.treeStack.Front;
					}
				case .Err(let err):
					if (this.treeStack.Count != 0)
						this.treeStack.Front.Dispose();

					return .Err(err);
			}
		}

		/// Deserializes JSON from a stream into a JsonValue tree.
		/// @param stream The stream containing JSON data.
		/// @returns The parsed JsonValue or a JsonParsingError on failure.
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

						return this.treeStack.Front;
					}
				case .Err(let err):
					if (this.treeStack.Count != 0)
						this.treeStack.Front.Dispose();

					return .Err(err);
			}
		}

		/// Adds a value to the current container (object or array).
		/// Optimized to minimize hash lookups for duplicate key handling.
		[Inline]
		private bool AddValue(JsonValue value)
		{
			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(value);
				return true;
			}

			var document = ref treeStack.Back;

			// Check if we're ignoring a duplicate structure first
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
						return false; //TODO: notify invalid key error
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

		/// Adds a value to a JSON object with optimized duplicate key handling.
		/// Uses single hash lookup via TryGetValue instead of ContainsKey + Get/Add.
		[Inline]
		private bool AddToObject(JsonObject jObj, JsonValue value)
		{
			// Use TryGetValue for single hash lookup
			if (jObj.data.object.TryGetValueAlt(currentKey, var existingValue))
			{
				// Key exists - handle based on duplicate behavior
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
						// Dispose the old content and overwrite
						existingValue.Dispose();
						jObj[currentKey] = value;
						currentKey = null;
						return true;
				}
			}
			else
			{
				// Key doesn't exist - add it
				jObj.Add(currentKey, value);
				currentKey = null;
				return true;
			}
		}

		[Inline]
		public bool Null()
		{
			return AddValue(JsonNull());
		}

		[Inline]
		public bool Bool(bool value)
		{
			return AddValue(JsonBool(value));
		}

		[Inline]
		public bool Number(double value)
		{
			return AddValue(JsonNumber(value));
		}

		[Inline]
		public bool Number(uint64 value)
		{
			return AddValue(JsonNumber(value));
		}
		
		[Inline]
		public bool Number(int64 value)
		{
			return AddValue(JsonNumber(value));
		}

		[Inline]
		public bool String(StringView value, bool copy)
		{
			return AddValue(JsonString(value));
		}

		public bool StartObject()
		{
			// Check if we're ignoring a duplicate structure first
			if (IsIgnoringDuplicate)
			{
				IgnoredDepthCounter++;
				return true;
			}

			if (treeStack.Count == 0)
			{
				// we are root here
				// root cant have key
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
							return false; //TODO: notify invalid key error

						let jObj = document.As<JsonObject>();

						// Use TryGetValue for single hash lookup
						if (jObj.data.object.TryGetValueAlt(currentKey, var existingValue))
						{
							// Key exists
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									return false;

								case .Ignore:
									IsIgnoringDuplicate = true;
									currentKey = null;
									return true;

								case .AlwaysRewrite:
									// dispose the old content
									existingValue.Dispose();
									let jVal = JsonObject();
									jObj[currentKey] = jVal;
									// add it to stack as current container
									treeStack.Add(jVal);
									currentKey = null;
									return true;
							}
						}
						else
						{
							let jVal = JsonObject();
							jObj.Add(currentKey, jVal);
							// add it to stack as current container
							treeStack.Add(jVal);
							currentKey = null;
							return true;
						}

					case .ARRAY:
						let jVal = JsonObject();
						document.As<JsonArray>().Add(jVal);

					// add it to stack as current container
						treeStack.Add(jVal);

						return true;
					default:
						return false;
				}
			}
		}

		[Inline]
		public bool Key(StringView str, bool copy)
		{
			currentKey = new:keyAlloc String(str);

			return true;
		}

		public bool EndObject()
		{
			if (IsIgnoringDuplicate)
			{
				if (IgnoredDepthCounter == 0)
				{
					// we are ending the ignored object with duplicated key
					IsIgnoringDuplicate = false;
					return true;
				}

				IgnoredDepthCounter--;
				return true;
			}

			if (treeStack.Count == 0)
				return false;

			//we dont pop root container
			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				// if the latest container we want to pop is not
				// an object then its a bad input
				if (val.type != .OBJECT)
					return false;
			}

			return true;
		}

		public bool StartArray()
		{
			// Check if we're ignoring a duplicate structure first
			if (IsIgnoringDuplicate)
			{
				IgnoredDepthCounter++;
				return true;
			}

			if (treeStack.Count == 0)
			{
				// we are root here
				// root cant have key
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
							return false; //TODO: notify invalid key error

						let jObj = document.As<JsonObject>();

						// Use TryGetValue for single hash lookup
						if (jObj.data.object.TryGetValueAlt(currentKey, var existingValue))
						{
							// Key exists
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									return false;

								case .Ignore:
									IsIgnoringDuplicate = true;
									currentKey = null;
									return true;

								case .AlwaysRewrite:
									// dispose the old content
									existingValue.Dispose();
									let jVal = JsonArray();
									jObj[currentKey] = jVal;
									// add it to stack as current container
									treeStack.Add(jVal);
									currentKey = null;
									return true;
							}
						}
						else
						{
							let jVal = JsonArray();
							jObj.Add(currentKey, jVal);
							// add it to stack as current container
							treeStack.Add(jVal);
							currentKey = null;
							return true;
						}

					case .ARRAY:
						let jVal = JsonArray();
						document.As<JsonArray>().Add(jVal);

					// add it to stack as current container
						treeStack.Add(jVal);

						return true;
					default:
						return false;
				}
			}
		}

		public bool EndArray()
		{
			if (IsIgnoringDuplicate)
			{
				if (IgnoredDepthCounter == 0)
				{
					// we are ending the ignored array with duplicated key
					IsIgnoringDuplicate = false;
					return true;
				}

				IgnoredDepthCounter--;
				return true;
			}

			if (treeStack.Count == 0)
				return false;

			//we don't pop root container
			if (treeStack.Count == 1)
				return true;

			if (treeStack.TryPopBack() case .Ok(let val))
			{
				// if the latest container we want to pop is not
				// an object then its a bad input
				if (val.type != .ARRAY)
					return false;
			}

			return true;
		}
	}
}
