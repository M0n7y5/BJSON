using System;
using System.IO;
using BJSON.Models;

namespace BJSON.Test;

/// Records the SAX calls JsonReader makes, in document order, so a test can assert what an
/// IHandler that is not the Deserializer sees. Events holds the calls separated by '|'.
class RecordingHandler : IHandler
{
	public String Events = new .() ~ delete _;

	/// Makes every Number callback refuse its value, which aborts the parse.
	public bool RefuseNumbers = false;

	/// Makes the Null callback refuse the literal, which aborts the parse.
	public bool RefuseNull = false;

	/// Makes the StartObject callback refuse the container, which aborts the parse.
	public bool RefuseStartObject = false;

	public bool Null()
	{
		Record("Null");
		return !RefuseNull;
	}

	public bool Bool(bool b)
	{
		Record(b ? "Bool:true" : "Bool:false");
		return true;
	}

	public bool Number(double n)
	{
		Record(scope $"Double:{n}");
		return !RefuseNumbers;
	}

	public bool Number(int64 n)
	{
		Record(scope $"Int64:{n}");
		return !RefuseNumbers;
	}

	public bool Number(uint64 n)
	{
		Record(scope $"UInt64:{n}");
		return !RefuseNumbers;
	}

	public bool String(StringView str, bool copy)
	{
		Record(scope $"String:{str}");
		return true;
	}

	public bool StartObject()
	{
		Record("StartObject");
		return !RefuseStartObject;
	}

	public bool Key(StringView str, bool copy)
	{
		Record(scope $"Key:{str}");
		return true;
	}

	public bool EndObject()
	{
		Record("EndObject");
		return true;
	}

	public bool StartArray()
	{
		Record("StartArray");
		return true;
	}

	public bool EndArray()
	{
		Record("EndArray");
		return true;
	}

	private void Record(StringView call)
	{
		if (!Events.IsEmpty)
			Events.Append('|');

		Events.Append(call);
	}
}

/// Tests for the IHandler contract, driven through JsonReader without a Deserializer.
class HandlerTest
{
	[Test(Name = "Handler: Event Sequence")]
	public static void T_EventSequence()
	{
		let json = """
			{"items": ["a", 1, true, null]}
			""";

		let handler = scope RecordingHandler();
		let reader = scope JsonReader(handler);

		Test.Assert(reader.Parse(scope StringStream(json, .Reference)) case .Ok, "Parse should succeed");
		Test.Assert(handler.Events == "StartObject|Key:items|StartArray|String:a|Int64:1|Bool:true|Null|EndArray|EndObject",
			scope $"Event sequence mismatch, got '{handler.Events}'");
	}

	[Test(Name = "Handler: Refused Value Aborts The Parse")]
	public static void T_RefusedValueAbortsParse()
	{
		let handler = scope RecordingHandler();
		handler.RefuseNumbers = true;

		let reader = scope JsonReader(handler);
		let result = reader.Parse(scope StringStream("[1, 2]", .Reference));

		Test.Assert(result case .Err(.InvalidValue(let line, let column)), "A refused number should end the parse");
		Test.Assert(line == 1, scope $"Expected line=1, got {line}");
		Test.Assert(column == 2, scope $"Expected column=2, got {column}");
		Test.Assert(handler.Events == "StartArray|Int64:1", scope $"Parse should stop at the refusal, got '{handler.Events}'");
	}

	[Test(Name = "Handler: Comments Follow The Reader Config")]
	public static void T_CommentsFollowReaderConfig()
	{
		let json = """
			// leading comment
			{"a": 1 /* trailing */}
			""";

		let accepting = scope RecordingHandler();
		var config = DeserializerConfig() { EnableComments = true };
		let configured = scope JsonReader(accepting, config);

		Test.Assert(configured.Parse(scope StringStream(json, .Reference)) case .Ok, "Comments should be skipped for any handler, not just Deserializer");
		Test.Assert(accepting.Events == "StartObject|Key:a|Int64:1|EndObject", scope $"Event sequence mismatch, got '{accepting.Events}'");

		let rejecting = scope RecordingHandler();
		let defaulted = scope JsonReader(rejecting);

		Test.Assert(defaulted.Parse(scope StringStream(json, .Reference)) case .Err, "The default config should reject comments");
		Test.Assert(rejecting.Events.IsEmpty, scope $"Nothing should reach the handler, got '{rejecting.Events}'");
	}

	[Test(Name = "Handler: Refused Null Reports InvalidValue")]
	public static void T_RefusedNullReportsInvalidValue()
	{
		let handler = scope RecordingHandler();
		handler.RefuseNull = true;

		let reader = scope JsonReader(handler);
		let result = reader.Parse(scope StringStream("null", .Reference));

		Test.Assert(result case .Err(.InvalidValue(let line, let column)), "A refused null should report InvalidValue, not UnexpectedToken");
		Test.Assert(line == 1 && column == 5, scope $"Expected line=1 column=5, got line={line} column={column}");
		Test.Assert(handler.Events == "Null", scope $"Only the refused call should be recorded, got '{handler.Events}'");
	}

	[Test(Name = "Handler: Refused StartObject Reports InvalidValue")]
	public static void T_RefusedStartObjectReportsInvalidValue()
	{
		let handler = scope RecordingHandler();
		handler.RefuseStartObject = true;

		let reader = scope JsonReader(handler);
		let result = reader.Parse(scope StringStream("{\"a\": 1}", .Reference));

		Test.Assert(result case .Err(.InvalidValue(let line, let column)), "A refused StartObject should report InvalidValue, not UnexpectedToken");
		Test.Assert(line == 1 && column == 2, scope $"Expected line=1 column=2, got line={line} column={column}");
		Test.Assert(handler.Events == "StartObject", scope $"Parse should stop at the refusal, got '{handler.Events}'");
	}
}
