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
			let reader = scope Reader(this);

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
			let reader = scope Reader(this);

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

		//[SkipCall]5
		void Log(String msg)
		{
			//Console.WriteLine(msg);
		}

		public bool Null()
		{
			Log("Null value");

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(JsonNull());
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					if (IsIgnoringDuplicate)
					{
						return true;
					}


					let jObj = document.As<JsonObject>();

					if (jObj.ContainsKey(currentKey) == false)
					{
						document.As<JsonObject>().Add(currentKey, JsonNull());
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

									document.As<JsonObject>()[currentKey] = JsonNull();
								}
						}
					}

					currentKey = null;
					break;
				case .ARRAY:
					if (IsIgnoringDuplicate)
					{
						return true;
					}

					document.As<JsonArray>().Add(JsonNull());
					break;
				default: return false;
			}

			return true;
		}

		public bool Bool(bool value)
		{
			Log(scope $"Bool value: {value}");

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(JsonBool(value));
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					if (IsIgnoringDuplicate)
					{
						return true;
					}

					let jObj = document.As<JsonObject>();

					if (jObj.ContainsKey(currentKey) == false)
					{
						document.As<JsonObject>().Add(currentKey, JsonBool(value));
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

									document.As<JsonObject>()[currentKey] = JsonBool(value);
								}
						}
					}

					currentKey = null;
					break;
				case .ARRAY:
					if (IsIgnoringDuplicate)
					{
						return true;
					}

					document.As<JsonArray>().Add(JsonBool(value));
					break;
				default: return false;
			}

			return true;
		}

		public bool Double(double value)
		{
			Log(scope $"Double value: {value}");

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(JsonNumber(value));
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					if (IsIgnoringDuplicate)
					{
						return true;
					}

					let jObj = document.As<JsonObject>();

					if (jObj.ContainsKey(currentKey) == false)
					{
						document.As<JsonObject>().Add(currentKey, JsonNumber(value));
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

									document.As<JsonObject>()[currentKey] = JsonNumber(value);
								}
						}
					}
					currentKey = null;
					break;
				case .ARRAY:
					if (IsIgnoringDuplicate)
					{
						return true;
					}

					document.As<JsonArray>().Add(JsonNumber(value));
					break;
				default: return false;
			}

			return true;
		}

		public bool String(StringView value, bool copy)
		{
			Log(scope $"String value: {value}");

			// root value
			if (treeStack.Count == 0)
			{
				treeStack.Add(JsonString(value));
				return true;
			}

			var document = ref treeStack.Back;

			switch (document.type)
			{
				case .OBJECT:
					if (currentKey == null)
						return false; //TODO: notify invalid key error

					if (IsIgnoringDuplicate)
					{
						currentKey = null;
						return true;
					}

					let jObj = document.As<JsonObject>();

					if (jObj.ContainsKey(currentKey) == false)
					{
						document.As<JsonObject>().Add(currentKey, JsonString(value));
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

									document.As<JsonObject>()[currentKey] = JsonString(value);
								}
						}
					}

					currentKey = null;
					break;
				case .ARRAY:
					if (IsIgnoringDuplicate)
					{
						currentKey = null;
						return true;
					}

					document.As<JsonArray>().Add(JsonString(value));
					break;
				default:
					return false;
			}

			return true;
		}

		public bool StartObject()
		{
			Log("Start Object");

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
			Log(scope $"Key value: {str}");

			currentKey = new:keyAlloc String(str);

			return true;
		}

		public bool EndObject()
		{
			Log("End Object");

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
			Log("Start Array");


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
			Log("End Array");

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
