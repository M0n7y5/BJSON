using System;
using BJSON;
using BJSON.Models;
using BJSON.Enums;

namespace BJSON.Test;

/// Number parsing and formatting contracts: integer boundaries, signed zero, and the
/// shortest round-trip guarantee of the double formatter.
class NumberTest
{
	[Test(Name = "Number Parsing - int64 Minimum")]
	public static void T_Int64MinimumBoundary()
	{
		var result = Json.Deserialize("-9223372036854775808");
		defer result.Dispose();

		if (result case .Ok(let json))
		{
			Test.Assert(json.type == .NUMBER_SIGNED, scope $"Expected a signed integer, got {json.type}");

			int64 value = json;
			Test.Assert(value == int64.MinValue, scope $"Expected {int64.MinValue}, got {value}");
		}
		else
		{
			Test.Assert(false, "int64 minimum should parse");
		}
	}

	[Test(Name = "Number Parsing - Negative Zero")]
	public static void T_NegativeZeroKeepsSign()
	{
		var result = Json.Deserialize("-0");
		defer result.Dispose();

		if (result case .Ok(let json))
		{
			double value = json;
			Test.Assert(value == 0.0, scope $"Expected zero, got {value}");
			Test.Assert(value.IsNegative, "Bare -0 should keep its sign");
		}
		else
		{
			Test.Assert(false, "-0 should parse");
		}
	}

	[Test(Name = "Regression: shortest round-trip for a 17 digit negative double")]
	public static void T_ShortestRoundTripWorstCase()
	{
		let value = -1.2551272886980567e-06;
		var json = JsonNumber(value);
		defer json.Dispose();

		let output = scope String();
		Test.Assert(Json.Serialize(json, output) case .Ok, "serialize must succeed");
		Test.Assert(output == "-1.2551272886980567e-06", scope $"got '{output}'");

		let reparsed = Json.Deserialize(output);
		Test.Assert(reparsed case .Ok(let val), "round-trip parse must succeed");
		Test.Assert((double)val == value, scope $"round-trip changed the value: {(double)val}");
	}
}
