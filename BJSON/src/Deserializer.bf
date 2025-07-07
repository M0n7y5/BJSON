using System;
using BJSON.Models;
using BJSON.Enums;
using System.IO;
using System.Diagnostics;
using System.Collections;
namespace BJSON
{
	public enum DuplicateKeyBehavior
	{
		/// Return error if duplicate key is found
		/// NOTE: This option is not RFC 8259 compliant
		ThrowError,
		/// Skip the duplicate
		Ignore,
		/// Rewrite previous value with the duplicate
		AlwaysRewrite
	}

	public struct DeserializerConfig
	{
		/// Enable support for comments in json string.
		/// This enables support for trailing and inline comments
		public bool EnableComments = false;

		/// Choose behavior if multiple objects with the same key
		/// are found during parsing
		public DuplicateKeyBehavior DuplicateBehavior = .AlwaysRewrite;
	}

	public class Deserializer : IHandler
	{
		// this will gonna contain only container types
		Queue<JsonValue> treeStack = new .(32) ~ delete _;

		String currentKey = null;
		BumpAllocator keyAlloc = new .() ~ delete _;

		bool IsIgnoringDuplicate = false;
		int IgnoredDepthCounter = 0;

		public DeserializerConfig Config = .();

		public this() { }

		public this(DeserializerConfig config)
		{
			this.Config = config;
		}

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

		private bool AddValue(JsonValue value)
		{
			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(value);
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
					{
						value.Dispose();
						return false; //TODO: notify invalid key error
					}

					if (IsIgnoringDuplicate)
					{
						value.Dispose();
						return true;
					}


					let jObj = document.As<JsonObject>();

					if (jObj.ContainsKey(currentKey) == false)
					{
						jObj.Add(currentKey, value);
					}
					else
					{
						switch (Config.DuplicateBehavior)
						{
							case .ThrowError:
								{
									value.Dispose();
									return false;
								}
							case .Ignore:
								{
									value.Dispose();
									return true;
								}
							case .AlwaysRewrite:
								{
									// dispose the old content
									jObj[currentKey].Dispose();

									jObj[currentKey] = value;
								}
						}
					}

					currentKey = null;
					break;
				case .ARRAY:
					if (IsIgnoringDuplicate)
					{
						value.Dispose();
						return true;
					}

					document.As<JsonArray>().Add(value);
					break;
				default:
					value.Dispose();
					return false;
			}

			return true;
		}

		public bool Null()
		{
			return AddValue(JsonNull());
		}

		public bool Bool(bool value)
		{
			return AddValue(JsonBool(value));
		}

		public bool Number(double value)
		{
			return AddValue(JsonNumber(value));
		}

		public bool Number(uint64 value)
		{
			return AddValue(JsonNumber(value));
		}
		

		public bool Number(int64 value)
		{
			return AddValue(JsonNumber(value));
		}

		public bool String(StringView value, bool copy)
		{
			return AddValue(JsonString(value));
		}

		public bool StartObject()
		{
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

						if (IsIgnoringDuplicate)
						{
							currentKey = null;
							IgnoredDepthCounter++;
							return true;
						}

						let jObj = document.As<JsonObject>();

						if (jObj.ContainsKey(currentKey) == false)
						{
							let jVal = JsonObject();
							jObj.Add(currentKey, jVal);
							// add it to stack as current container
							treeStack.Add(jVal);
						}
						else
						{
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									{
										return false;
									}
								case .Ignore:
									{
										IsIgnoringDuplicate = true;
									}
								case .AlwaysRewrite:
									{
										// dispose the old content
										jObj[currentKey].Dispose();

										let jVal = JsonObject();
										jObj.Add(currentKey, jVal);
										// add it to stack as current container
										treeStack.Add(jVal);
									}
							}
						}

						currentKey = null;
						return true;
					case .ARRAY:
						if (IsIgnoringDuplicate)
						{
							IgnoredDepthCounter++;
							return true;
						}
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

						if (IsIgnoringDuplicate)
						{
							IgnoredDepthCounter++;
							return true;
						}

						let jObj = document.As<JsonObject>();

						if (jObj.ContainsKey(currentKey) == false)
						{
							let jVal = JsonArray();
							document.As<JsonObject>().Add(currentKey, jVal);

							// add it to stack as current container
							treeStack.Add(jVal);
						}
						else
						{
							switch (Config.DuplicateBehavior)
							{
								case .ThrowError:
									{
										return false;
									}
								case .Ignore:
									{
										return true;
										//IsIgnoringDuplicate = true;
									}
								case .AlwaysRewrite:
									{
										// dispose the old content
										jObj[currentKey].Dispose();
										let jVal = JsonArray();
										document.As<JsonObject>()[currentKey] = jVal;
										// add it to stack as current container
										treeStack.Add(jVal);
									}
							}
						}

						currentKey = null;
						return true;
					case .ARRAY:
						if (IsIgnoringDuplicate)
						{
							IgnoredDepthCounter++;
							return true;
						}

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
