using BJSON.Attributes;
using BJSON;
using BJSON.Models;
using BJSON.Enums;
using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

namespace BJSON.Test;

/// Test enum for serialization tests
enum PlayerStatus
{
	Active,
	Inactive,
	Banned
}

/// Simple nested object for testing
[JsonObject]
class NestedInfo
{
	public String Description = new .() ~ delete _;
	public int Value;
}

/// Main test class with various field types
[JsonObject]
class Player
{
	public String Name = new .() ~ delete _;
	public int Health;
	public float Speed;
	public bool IsAlive;

	[JsonPropertyName("player_level")]
	public int Level;

	public int? OptionalScore;

	public PlayerStatus Status;

	// Nested object (pre-allocated)
	public NestedInfo Info = new .() ~ delete _;

	public List<int> Scores = new .() ~ delete _;

	// List of strings (each item will be heap allocated)
	public List<String> Tags = new .() ~ DeleteContainerAndItems!(_);

	public Dictionary<String, int> Stats = new .() ~ DeleteDictionaryAndKeys!(_);

	[JsonIgnore(Condition = .Always)]
	public int InternalId;

	public int[3] Position;
}

/// Test class for [JsonInclude] on private fields
[JsonObject]
class PrivateFieldTest
{
	public String PublicName = new .() ~ delete _;

	[JsonInclude]
	private int _privateValue;

	public int GetPrivateValue() => _privateValue;
	public void SetPrivateValue(int val) => _privateValue = val;
}

/// Test class for List of objects
[JsonObject]
class Team
{
	public String TeamName = new .() ~ delete _;
	public List<Player> Members = new .() ~ DeleteContainerAndItems!(_);
}

/// Test class for Dictionary of objects
[JsonObject]
class GameData
{
	public Dictionary<String, NestedInfo> Metadata = new .() ~ {
		for (let kv in _)
		{
			delete kv.key;
			delete kv.value;
		}
		delete _;
	};
}

/// Date carried through JSON by the converter its own type names, with no attribute on the fields
/// that use it and no [JsonObject] of its own.
[JsonConverter(typeof(SimpleDateConverter))]
struct SimpleDate
{
	public int Year;
	public int Month;
	public int Day;

	public this(int year, int month, int day)
	{
		Year = year;
		Month = month;
		Day = day;
	}

	public override void ToString(String str)
	{
		str.AppendF($"{Year:D4}-{Month:D2}-{Day:D2}");
	}

	public static Result<SimpleDate> Parse(StringView str)
	{
		if (str.Length != 10)
			return .Err;

		var date = SimpleDate(0, 0, 0);

		if (int.Parse(str.Substring(0, 4)) case .Ok(let year))
			date.Year = year;
		else
			return .Err;

		if (int.Parse(str.Substring(5, 2)) case .Ok(let month))
			date.Month = month;
		else
			return .Err;

		if (int.Parse(str.Substring(8, 2)) case .Ok(let day))
			date.Day = day;
		else
			return .Err;

		return .Ok(date);
	}
}

/// Writes SimpleDate as a "YYYY-MM-DD" JSON string and reads it back.
class SimpleDateConverter : IJsonConverter<SimpleDate>
{
	public Result<void> WriteJson(Stream stream, SimpleDate value)
	{
		if (BJSON.JsonWriter.WriteString(stream, value.ToString(.. scope String())) case .Err)
			return .Err;

		return .Ok;
	}

	public Result<SimpleDate> ReadJson(JsonValue value)
	{
		if (!value.IsString())
			return .Err;

		if (SimpleDate.Parse((StringView)value) case .Ok(let date))
			return .Ok(date);

		return .Err;
	}
}

/// Test class whose fields carry no [JsonConverter]: the converter comes from SimpleDate itself,
/// on the plain field and on the list element alike.
[JsonObject]
class Appointment
{
	public String Subject = new .() ~ delete _;
	public SimpleDate Day;
	public List<SimpleDate> Reminders = new .() ~ delete _;
}

/// Test class for a Dictionary with enum values.
[JsonObject]
class StatusBoard
{
	public Dictionary<String, PlayerStatus> Statuses = new .() ~ DeleteDictionaryAndKeys!(_);
}

/// Test class for sized arrays of String and of enum. The String slots are allocated here, so this
/// type owns them: the emitted read fills them in place.
[JsonObject]
class LabelSet
{
	public String[3] Labels = .(new String(), new String(), new String()) ~ {
		for (int i < 3)
			delete _[i];
	};

	public PlayerStatus[2] Modes;
}

class ReflectTest
{
	[Test(Name = "Reflection: Basic Deserialization")]
	public static void T_BasicDeserialization()
	{
		let json = """
			{
				"Name": "TestPlayer",
				"Health": 100,
				"Speed": 5.5,
				"IsAlive": true,
				"player_level": 42,
				"Status": "Active",
				"Info": {
					"Description": "A test player",
					"Value": 999
				},
				"Scores": [10, 20, 30],
				"Tags": ["warrior", "hero"],
				"Stats": {"strength": 10, "agility": 15},
				"Position": [1, 2, 3]
			}
			""";

		var parseResult = Json.Deserialize(json);
		defer parseResult.Dispose();

		Test.Assert(parseResult case .Ok, "Failed to parse JSON");

		let player = scope Player();
		let deserializeResult = player.JsonDeserialize(parseResult.Value);

		Test.Assert(deserializeResult case .Ok, "Failed to deserialize Player");

		Test.Assert(player.Name == "TestPlayer", scope $"Expected 'TestPlayer', got '{player.Name}'");
		Test.Assert(player.Health == 100, scope $"Expected Health=100, got {player.Health}");
		Test.Assert(Math.Abs(player.Speed - 5.5f) < 0.01f, scope $"Expected Speed=5.5, got {player.Speed}");
		Test.Assert(player.IsAlive == true, "Expected IsAlive=true");
		Test.Assert(player.Level == 42, scope $"Expected Level=42, got {player.Level}");

		Test.Assert(player.Status == .Active, scope $"Expected Status=Active, got {player.Status}");

		Test.Assert(player.Info.Description == "A test player", scope $"Expected Info.Description='A test player', got '{player.Info.Description}'");
		Test.Assert(player.Info.Value == 999, scope $"Expected Info.Value=999, got {player.Info.Value}");

		Test.Assert(player.Scores.Count == 3, scope $"Expected 3 scores, got {player.Scores.Count}");
		Test.Assert(player.Scores[0] == 10 && player.Scores[1] == 20 && player.Scores[2] == 30, "Scores mismatch");

		Test.Assert(player.Tags.Count == 2, scope $"Expected 2 tags, got {player.Tags.Count}");
		Test.Assert(player.Tags[0] == "warrior", scope $"Expected first tag 'warrior', got '{player.Tags[0]}'");

		Test.Assert(player.Stats.Count == 2, scope $"Expected 2 stats, got {player.Stats.Count}");
		Test.Assert(player.Stats.ContainsKeyAlt("strength"), "Missing 'strength' stat");
		if (player.Stats.TryGetValueAlt("strength", let strengthVal))
			Test.Assert(strengthVal == 10, "Wrong strength value");

		Test.Assert(player.Position[0] == 1 && player.Position[1] == 2 && player.Position[2] == 3, "Position mismatch");

		Debug.WriteLine("Reflection: Basic Deserialization - PASSED");
	}

	[Test(Name = "Reflection: Basic Serialization")]
	public static void T_BasicSerialization()
	{
		let player = scope Player();
		player.Name.Set("SerializeTest");
		player.Health = 75;
		player.Speed = 3.14f;
		player.IsAlive = false;
		player.Level = 10;
		player.Status = .Inactive;
		player.Info.Description.Set("Serialized player");
		player.Info.Value = 123;
		player.Scores.Add(1);
		player.Scores.Add(2);
		player.Tags.Add(new String("test"));
		player.Stats.Add(new String("power"), 50);
		player.Position[0] = 10;
		player.Position[1] = 20;
		player.Position[2] = 30;

		let buffer = scope String();
		let result = Json.Serialize(player, buffer);

		Test.Assert(result case .Ok, "Serialization failed");
		Test.Assert(buffer.Length > 0, "Empty serialization output");

		var parseResult = Json.Deserialize(buffer);
		defer parseResult.Dispose();

		Test.Assert(parseResult case .Ok, scope $"Failed to parse serialized JSON: {buffer}");

		let root = parseResult.Value.AsObject().Value;
		Test.Assert((StringView)root.GetValue("Name").Value == "SerializeTest", "Name mismatch");
		Test.Assert((int)root.GetValue("Health").Value == 75, "Health mismatch");
		Test.Assert(root.GetValue("IsAlive").Value == false, "IsAlive mismatch");

		Test.Assert(root.ContainsKey("player_level"), "Custom property name 'player_level' not found");
		Test.Assert((int)root.GetValue("player_level").Value == 10, "Level mismatch");

		Test.Assert(!root.ContainsKey("InternalId"), "InternalId should be ignored");

		Debug.WriteLine("Reflection: Basic Serialization - PASSED");
	}

	[Test(Name = "Reflection: Round Trip")]
	public static void T_RoundTrip()
	{
		let original = scope Player();
		original.Name.Set("RoundTrip");
		original.Health = 50;
		original.Speed = 2.5f;
		original.IsAlive = true;
		original.Level = 5;
		original.Status = .Banned;
		original.Info.Description.Set("Round trip test");
		original.Info.Value = 42;
		original.Scores.Add(100);
		original.Scores.Add(200);

		let buffer = scope String();
		Test.Assert(Json.Serialize(original, buffer) case .Ok, "Serialization failed");

		let stream = scope StringStream(buffer, .Reference);
		let restored = scope Player();
		Test.Assert(Json.Deserialize<Player>(stream, restored) case .Ok, "Deserialization failed");

		Test.Assert(restored.Name == original.Name, "Name mismatch after round trip");
		Test.Assert(restored.Health == original.Health, "Health mismatch after round trip");
		Test.Assert(Math.Abs(restored.Speed - original.Speed) < 0.01f, "Speed mismatch after round trip");
		Test.Assert(restored.IsAlive == original.IsAlive, "IsAlive mismatch after round trip");
		Test.Assert(restored.Level == original.Level, "Level mismatch after round trip");
		Test.Assert(restored.Status == original.Status, "Status mismatch after round trip");
		Test.Assert(restored.Info.Value == original.Info.Value, "Info.Value mismatch after round trip");

		Debug.WriteLine("Reflection: Round Trip - PASSED");
	}

	[Test(Name = "Reflection: Optional/Nullable Fields")]
	public static void T_NullableFields()
	{
		let jsonWithOptional = """
			{
				"Name": "Test",
				"Health": 1,
				"Speed": 1.0,
				"IsAlive": true,
				"player_level": 1,
				"OptionalScore": 42,
				"Status": "Active",
				"Info": {"Description": "", "Value": 0},
				"Scores": [],
				"Tags": [],
				"Stats": {},
				"Position": [0, 0, 0]
			}
			""";

		var result1 = Json.Deserialize(jsonWithOptional);
		defer result1.Dispose();
		Test.Assert(result1 case .Ok, "Parse failed");

		let player1 = scope Player();
		Test.Assert(player1.JsonDeserialize(result1.Value) case .Ok, "Deserialize failed");
		Test.Assert(player1.OptionalScore.HasValue, "OptionalScore should have value");
		Test.Assert(player1.OptionalScore.Value == 42, "OptionalScore should be 42");

		let jsonWithoutOptional = """
			{
				"Name": "Test",
				"Health": 1,
				"Speed": 1.0,
				"IsAlive": true,
				"player_level": 1,
				"Status": "Active",
				"Info": {"Description": "", "Value": 0},
				"Scores": [],
				"Tags": [],
				"Stats": {},
				"Position": [0, 0, 0]
			}
			""";

		var result2 = Json.Deserialize(jsonWithoutOptional);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let player2 = scope Player();
		player2.OptionalScore = null;
		Test.Assert(player2.JsonDeserialize(result2.Value) case .Ok, "Deserialize failed");

		Debug.WriteLine("Reflection: Optional/Nullable Fields - PASSED");
	}

	[Test(Name = "Reflection: Enum as Number")]
	public static void T_EnumAsNumber()
	{
		let json = """
			{
				"Name": "Test",
				"Health": 1,
				"Speed": 1.0,
				"IsAlive": true,
				"player_level": 1,
				"Status": 2,
				"Info": {"Description": "", "Value": 0},
				"Scores": [],
				"Tags": [],
				"Stats": {},
				"Position": [0, 0, 0]
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let player = scope Player();
		Test.Assert(player.JsonDeserialize(result.Value) case .Ok, "Deserialize failed");
		Test.Assert(player.Status == .Banned, scope $"Expected Status=Banned (2), got {player.Status}");

		Debug.WriteLine("Reflection: Enum as Number - PASSED");
	}

	[Test(Name = "Reflection: Private Field with JsonInclude")]
	public static void T_PrivateFieldWithJsonInclude()
	{
		let json = """
			{
				"PublicName": "Test",
				"_privateValue": 42
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj = scope PrivateFieldTest();
		Test.Assert(obj.JsonDeserialize(result.Value) case .Ok, "Deserialize failed");
		Test.Assert(obj.PublicName == "Test", "PublicName mismatch");
		Test.Assert(obj.GetPrivateValue() == 42, scope $"Expected private value 42, got {obj.GetPrivateValue()}");

		let buffer = scope String();
		Test.Assert(Json.Serialize(obj, buffer) case .Ok, "Serialize failed");
		Test.Assert(buffer.Contains("_privateValue"), "Private field should be in serialized output");

		Debug.WriteLine("Reflection: Private Field with JsonInclude - PASSED");
	}

	[Test(Name = "Reflection: List of Objects")]
	public static void T_ListOfObjects()
	{
		let json = """
			{
				"TeamName": "Heroes",
				"Members": [
					{
						"Name": "Player1",
						"Health": 100,
						"Speed": 5.0,
						"IsAlive": true,
						"player_level": 10,
						"Status": "Active",
						"Info": {"Description": "First", "Value": 1},
						"Scores": [10],
						"Tags": [],
						"Stats": {},
						"Position": [0, 0, 0]
					},
					{
						"Name": "Player2",
						"Health": 80,
						"Speed": 6.0,
						"IsAlive": false,
						"player_level": 8,
						"Status": "Inactive",
						"Info": {"Description": "Second", "Value": 2},
						"Scores": [20],
						"Tags": [],
						"Stats": {},
						"Position": [1, 1, 1]
					}
				]
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let team = scope Team();
		Test.Assert(team.JsonDeserialize(result.Value) case .Ok, "Deserialize failed");

		Test.Assert(team.TeamName == "Heroes", scope $"Expected TeamName='Heroes', got '{team.TeamName}'");
		Test.Assert(team.Members.Count == 2, scope $"Expected 2 members, got {team.Members.Count}");
		Test.Assert(team.Members[0].Name == "Player1", "First member name mismatch");
		Test.Assert(team.Members[1].Name == "Player2", "Second member name mismatch");
		Test.Assert(team.Members[0].Health == 100, "First member health mismatch");
		Test.Assert(team.Members[1].IsAlive == false, "Second member IsAlive mismatch");

		Debug.WriteLine("Reflection: List of Objects - PASSED");
	}

	[Test(Name = "Reflection: Dictionary of Objects")]
	public static void T_DictionaryOfObjects()
	{
		let json = """
			{
				"Metadata": {
					"config1": {"Description": "First config", "Value": 100},
					"config2": {"Description": "Second config", "Value": 200}
				}
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let data = scope GameData();
		Test.Assert(data.JsonDeserialize(result.Value) case .Ok, "Deserialize failed");

		Test.Assert(data.Metadata.Count == 2, scope $"Expected 2 metadata entries, got {data.Metadata.Count}");
		Test.Assert(data.Metadata.ContainsKeyAlt("config1"), "Missing 'config1'");
		Test.Assert(data.Metadata.ContainsKeyAlt("config2"), "Missing 'config2'");

		if (data.Metadata.TryGetValueAlt("config1", let val1))
		{
			Test.Assert(val1.Description == "First config", "config1 description mismatch");
			Test.Assert(val1.Value == 100, "config1 value mismatch");
		}

		Debug.WriteLine("Reflection: Dictionary of Objects - PASSED");
	}

	[Test(Name = "Reflection: Error on Missing Required Field")]
	public static void T_ErrorOnMissingRequired()
	{
		let json = """
			{
				"OptionalField": "Test"
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj = scope RequiredFieldClass();
		let deserializeResult = obj.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Err(.MissingRequiredField(let path, let fieldName)), "Should fail on missing required field 'RequiredField'");
		Test.Assert(fieldName == "RequiredField", scope $"Expected fieldName='RequiredField', got '{fieldName}'");
		Test.Assert(path == "/RequiredField", scope $"Expected path='/RequiredField', got '{path}'");

		Debug.WriteLine("Reflection: Error on Missing Required Field - PASSED");
	}

	[Test(Name = "Reflection: Error on Type Mismatch")]
	public static void T_ErrorOnTypeMismatch()
	{
		let json = """
			{
				"Name": "Test",
				"Health": "not a number",
				"Speed": 1.0,
				"IsAlive": true,
				"player_level": 1,
				"Status": "Active",
				"Info": {"Description": "", "Value": 0},
				"Scores": [],
				"Tags": [],
				"Stats": {},
				"Position": [0, 0, 0]
			}
			""";

		var result = Json.Deserialize(json);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let player = scope Player();
		let deserializeResult = player.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Err(.TypeMismatch(let path, let expected, let actual)), "Should fail on type mismatch for 'Health'");
		Test.Assert(path == "/Health", scope $"Expected path='/Health', got '{path}'");
		Test.Assert(expected == "number", scope $"Expected expected='number', got '{expected}'");
		Test.Assert(actual == "string", scope $"Expected actual='string', got '{actual}'");

		Debug.WriteLine("Reflection: Error on Type Mismatch - PASSED");
	}

	[Test(Name = "Reflection: String Escaping in Serialization")]
	public static void T_StringEscaping()
	{
		let player = scope Player();
		player.Name.Set("Test\"With\\Escapes\nNewline");
		player.Health = 1;
		player.Speed = 1.0f;
		player.IsAlive = true;
		player.Level = 1;
		player.Status = .Active;
		player.Info.Description.Set("");
		player.Info.Value = 0;

		let buffer = scope String();
		Test.Assert(Json.Serialize(player, buffer) case .Ok, "Serialization failed");

		var parseResult = Json.Deserialize(buffer);
		defer parseResult.Dispose();
		Test.Assert(parseResult case .Ok, scope $"Failed to parse serialized JSON with escapes: {buffer}");

		let root = parseResult.Value.AsObject().Value;
		let name = (StringView)root.GetValue("Name").Value;
		Test.Assert(name == "Test\"With\\Escapes\nNewline", scope $"String escaping failed, got: {name}");

		Debug.WriteLine("Reflection: String Escaping in Serialization - PASSED");
	}

	[Test(Name = "Reflection: Allocating Deserialize API")]
	public static void T_AllocatingDeserialize()
	{
		let json = """
			{
				"Description": "Test allocation",
				"Value": 999
			}
			""";

		let stream = scope StringStream(json, .Reference);
		var result = Json.Deserialize<NestedInfo>(stream);

		Test.Assert(result case .Ok, "Deserialize failed");

		let info = result.Value;
		defer delete info;

		Test.Assert(info.Description == "Test allocation", scope $"Expected 'Test allocation', got '{info.Description}'");
		Test.Assert(info.Value == 999, scope $"Expected 999, got {info.Value}");

		Debug.WriteLine("Reflection: Allocating Deserialize API - PASSED");
	}

	[Test(Name = "Reflection: Stream-based Serialization")]
	public static void T_StreamSerialization()
	{
		let info = scope NestedInfo();
		info.Description.Set("Stream test");
		info.Value = 42;

		let memStream = scope MemoryStream();
		Test.Assert(Json.Serialize(info, memStream) case .Ok, "Stream serialization failed");

		memStream.Position = 0;
		let buffer = scope String();
		let len = (int)memStream.Length;
		buffer.Reserve(len);
		for (int i = 0; i < len; i++)
		{
			if (memStream.Read<char8>() case .Ok(let c))
				buffer.Append(c);
		}

		var parseResult = Json.Deserialize(buffer);
		defer parseResult.Dispose();
		Test.Assert(parseResult case .Ok, scope $"Failed to parse stream output: {buffer}");

		let root = parseResult.Value.AsObject().Value;
		Test.Assert((StringView)root.GetValue("Description").Value == "Stream test", "Description mismatch");
		Test.Assert((int)root.GetValue("Value").Value == 42, "Value mismatch");

		Debug.WriteLine("Reflection: Stream-based Serialization - PASSED");
	}

	[Test(Name = "Reflection: Inheritance")]
	public static void T_Inheritance()
	{
		let derived = scope DerivedClass();
		derived.BaseField = 42;
		derived.DerivedField.Set("test");

		let buffer = scope String();
		Test.Assert(Json.Serialize(derived, buffer) case .Ok, "Serialization failed");

		Debug.WriteLine(scope $"Serialized JSON: {buffer}");

		Test.Assert(buffer.Contains("BaseField"), scope $"Base field not serialized. JSON: {buffer}");
		Test.Assert(buffer.Contains("DerivedField"), scope $"Derived field not serialized. JSON: {buffer}");

		let json = """
			{
				"BaseField": 100,
				"DerivedField": "restored"
			}
			""";
		let stream = scope StringStream(json, .Reference);
		let restored = scope DerivedClass();
		let deserializeResult = Json.Deserialize<DerivedClass>(stream, restored);
		Test.Assert(deserializeResult case .Ok, scope $"Deserialization failed");

		Test.Assert(restored.BaseField == 100, scope $"BaseField mismatch: {restored.BaseField}");
		Test.Assert(restored.DerivedField == "restored", scope $"DerivedField mismatch: {restored.DerivedField}");

		Debug.WriteLine("Reflection: Inheritance - PASSED");
	}

	[Test(Name = "Reflection: JsonRequired Attribute")]
	public static void T_JsonRequiredAttribute()
	{
		let jsonMissing = """
			{
				"OptionalField": "test"
			}
			""";

		var result = Json.Deserialize(jsonMissing);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj1 = scope RequiredFieldClass();
		let deserializeResult = obj1.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Err, "Should fail on missing required field 'RequiredField'");

		let jsonPresent = """
			{
				"RequiredField": "required",
				"OptionalField": "optional"
			}
			""";

		var result2 = Json.Deserialize(jsonPresent);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let obj2 = scope RequiredFieldClass();
		let deserializeResult2 = obj2.JsonDeserialize(result2.Value);
		Test.Assert(deserializeResult2 case .Ok, "Deserialization should succeed with required field present");
		Test.Assert(obj2.RequiredField == "required", scope $"Expected RequiredField='required', got '{obj2.RequiredField}'");
		Test.Assert(obj2.OptionalField == "optional", scope $"Expected OptionalField='optional', got '{obj2.OptionalField}'");

		Debug.WriteLine("Reflection: JsonRequired Attribute - PASSED");
	}

	[Test(Name = "Reflection: JsonOptional Attribute")]
	public static void T_JsonOptionalAttribute()
	{
		let jsonMissing = """
			{
				"RequiredField": "test"
			}
			""";

		var result = Json.Deserialize(jsonMissing);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj = scope OptionalFieldClass();
		let deserializeResult = obj.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Ok, "Deserialization should succeed because OptionalField is marked [JsonOptional]");
		Test.Assert(obj.RequiredField == "test", scope $"Expected RequiredField='test', got '{obj.RequiredField}'");
		Test.Assert(obj.OptionalField == 0, "OptionalField should have default value 0 when missing");

		let jsonPresent = """
			{
				"RequiredField": "test",
				"OptionalField": 42
			}
			""";

		var result2 = Json.Deserialize(jsonPresent);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let obj2 = scope OptionalFieldClass();
		let deserializeResult2 = obj2.JsonDeserialize(result2.Value);
		Test.Assert(deserializeResult2 case .Ok, "Deserialization should succeed");
		Test.Assert(obj2.OptionalField == 42, scope $"Expected OptionalField=42, got {obj2.OptionalField}");

		Debug.WriteLine("Reflection: JsonOptional Attribute - PASSED");
	}

	[Test(Name = "Reflection: Class Fields Are Optional By Default")]
	public static void T_ClassFieldsOptionalByDefault()
	{
		let jsonWithoutNested = """
			{
				"Name": "Test",
				"Value": 42
			}
			""";

		var result = Json.Deserialize(jsonWithoutNested);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj = scope ClassWithNestedObject();
		let deserializeResult = obj.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Ok, "Deserialization should succeed because NestedObject is optional by default");
		Test.Assert(obj.Name == "Test", scope $"Expected Name='Test', got '{obj.Name}'");
		Test.Assert(obj.Value == 42, scope $"Expected Value=42, got {obj.Value}");
		Test.Assert(obj.NestedObject == null, "NestedObject should be null when missing from JSON");

		let jsonWithNested = """
			{
				"Name": "Test",
				"Value": 42,
				"NestedObject": {
					"Description": "nested",
					"Value": 99
				}
			}
			""";

		var result2 = Json.Deserialize(jsonWithNested);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let obj2 = scope ClassWithNestedObject();
		obj2.NestedObject = scope NestedInfo(); // Pre-allocate for deserialization
		let deserializeResult2 = obj2.JsonDeserialize(result2.Value);
		Test.Assert(deserializeResult2 case .Ok, "Deserialization should succeed");
		Test.Assert(obj2.NestedObject != null, "NestedObject should be set");
		Test.Assert(obj2.NestedObject.Value == 99, scope $"Expected NestedObject.Value=99, got {obj2.NestedObject.Value}");

		Debug.WriteLine("Reflection: Class Fields Are Optional By Default - PASSED");
	}

	[Test(Name = "Reflection: Both Attributes with Nested Objects")]
	public static void T_RequiredWithNestedObjects()
	{
		let jsonMissingNested = """
			{
				"Name": "Test"
			}
			""";

		var result = Json.Deserialize(jsonMissingNested);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj1 = scope ClassWithRequiredNested();
		let deserializeResult1 = obj1.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult1 case .Err, "Should fail on missing required nested object");

		let jsonWithNested = """
			{
				"Name": "Test",
				"RequiredNested": {
					"Description": "required",
					"Value": 100
				}
			}
			""";

		var result2 = Json.Deserialize(jsonWithNested);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let obj2 = scope ClassWithRequiredNested();
		obj2.RequiredNested = scope NestedInfo(); // Pre-allocate
		let deserializeResult2 = obj2.JsonDeserialize(result2.Value);
		Test.Assert(deserializeResult2 case .Ok, "Deserialization should succeed with required nested object present");
		Test.Assert(obj2.RequiredNested.Value == 100, scope $"Expected RequiredNested.Value=100, got {obj2.RequiredNested.Value}");

		Debug.WriteLine("Reflection: Both Attributes with Nested Objects - PASSED");
	}

	[Test(Name = "Reflection: DefaultBehavior Required")]
	public static void T_DefaultBehaviorRequired()
	{
		let jsonMissingField = """
			{
				"Name": "Test",
				"Score": 100
			}
			""";

		var result = Json.Deserialize(jsonMissingField);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj1 = scope AllRequiredClass();
		let deserializeResult = obj1.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Err, "Should fail on missing required field 'Level'");

		let jsonComplete = """
			{
				"Name": "Test",
				"Score": 100,
				"Level": 5
			}
			""";

		var result2 = Json.Deserialize(jsonComplete);
		defer result2.Dispose();
		Test.Assert(result2 case .Ok, "Parse failed");

		let obj2 = scope AllRequiredClass();
		let deserializeResult2 = obj2.JsonDeserialize(result2.Value);
		Test.Assert(deserializeResult2 case .Ok, "Deserialization should succeed with all required fields present");
		Test.Assert(obj2.Name == "Test", scope $"Expected Name='Test', got '{obj2.Name}'");
		Test.Assert(obj2.Score == 100, scope $"Expected Score=100, got {obj2.Score}");
		Test.Assert(obj2.Level == 5, scope $"Expected Level=5, got {obj2.Level}");

		Debug.WriteLine("Reflection: DefaultBehavior Required - PASSED");
	}

	[Test(Name = "Reflection: DefaultBehavior Required with JsonOptional")]
	public static void T_DefaultBehaviorRequiredWithOptional()
	{
		let jsonWithOptionalMissing = """
			{
				"RequiredField": "test",
				"AnotherRequired": 42
			}
			""";

		var result = Json.Deserialize(jsonWithOptionalMissing);
		defer result.Dispose();
		Test.Assert(result case .Ok, "Parse failed");

		let obj = scope MixedRequiredOptionalClass();
		let deserializeResult = obj.JsonDeserialize(result.Value);
		Test.Assert(deserializeResult case .Ok, "Deserialization should succeed because OptionalField is marked [JsonOptional]");
		Test.Assert(obj.RequiredField == "test", scope $"Expected RequiredField='test', got '{obj.RequiredField}'");
		Test.Assert(obj.AnotherRequired == 42, scope $"Expected AnotherRequired=42, got {obj.AnotherRequired}");
		Test.Assert(obj.OptionalField == 0, "OptionalField should have default value 0 when missing");

		Debug.WriteLine("Reflection: DefaultBehavior Required with JsonOptional - PASSED");
	}

	[Test(Name = "Reflection: Converter On The Field Type")]
	public static void T_ConverterOnFieldType()
	{
		let original = scope Appointment();
		original.Subject.Set("Standup");
		original.Day = SimpleDate(2026, 3, 9);
		original.Reminders.Add(SimpleDate(2026, 3, 8));
		original.Reminders.Add(SimpleDate(2026, 3, 7));

		let buffer = scope String();
		Test.Assert(Json.Serialize(original, buffer) case .Ok, "Serialization failed");
		Test.Assert(buffer.Contains("\"2026-03-09\""), scope $"Expected the converter's date string in the output, got {buffer}");

		let restored = scope Appointment();
		Test.Assert(Json.Deserialize<Appointment>(buffer, restored) case .Ok, scope $"Deserialization failed for {buffer}");

		Test.Assert(restored.Subject == "Standup", scope $"Expected Subject='Standup', got '{restored.Subject}'");
		Test.Assert(((restored.Day.Year == 2026) && (restored.Day.Month == 3) && (restored.Day.Day == 9)), scope $"Expected Day=2026-03-09, got {restored.Day}");
		Test.Assert(restored.Reminders.Count == 2, scope $"Expected 2 reminders, got {restored.Reminders.Count}");
		Test.Assert(restored.Reminders[0].Day == 8, scope $"Expected first reminder 2026-03-08, got {restored.Reminders[0]}");
		Test.Assert(restored.Reminders[1].Day == 7, scope $"Expected second reminder 2026-03-07, got {restored.Reminders[1]}");

		Debug.WriteLine("Reflection: Converter On The Field Type - PASSED");
	}

	[Test(Name = "Reflection: Dictionary With Enum Values")]
	public static void T_DictionaryWithEnumValues()
	{
		let original = scope StatusBoard();
		original.Statuses.Add(new String("alice"), .Active);
		original.Statuses.Add(new String("bob"), .Banned);

		let buffer = scope String();
		Test.Assert(Json.Serialize(original, buffer) case .Ok, "Serialization failed");

		let restored = scope StatusBoard();
		Test.Assert(Json.Deserialize<StatusBoard>(buffer, restored) case .Ok, scope $"Deserialization failed for {buffer}");
		Test.Assert(restored.Statuses.Count == 2, scope $"Expected 2 entries, got {restored.Statuses.Count}");

		if (restored.Statuses.TryGetValueAlt("alice", let aliceStatus))
			Test.Assert(aliceStatus == .Active, scope $"Expected alice=Active, got {aliceStatus}");
		else
			Test.Assert(false, scope $"Missing 'alice' entry in {buffer}");

		if (restored.Statuses.TryGetValueAlt("bob", let bobStatus))
			Test.Assert(bobStatus == .Banned, scope $"Expected bob=Banned, got {bobStatus}");
		else
			Test.Assert(false, scope $"Missing 'bob' entry in {buffer}");

		let numericJson = """
			{"Statuses": {"carol": 1}}
			""";

		let fromNumber = scope StatusBoard();
		Test.Assert(Json.Deserialize<StatusBoard>(numericJson, fromNumber) case .Ok, "A numeric enum value should deserialize");

		if (fromNumber.Statuses.TryGetValueAlt("carol", let carolStatus))
			Test.Assert(carolStatus == .Inactive, scope $"Expected carol=Inactive, got {carolStatus}");
		else
			Test.Assert(false, "Missing 'carol' entry");

		Debug.WriteLine("Reflection: Dictionary With Enum Values - PASSED");
	}

	[Test(Name = "Reflection: Sized Array Of Strings And Enums")]
	public static void T_SizedArrayOfStringsAndEnums()
	{
		let original = scope LabelSet();
		original.Labels[0].Set("alpha");
		original.Labels[1].Set("beta");
		original.Labels[2].Set("gamma");
		original.Modes[0] = .Inactive;
		original.Modes[1] = .Banned;

		let buffer = scope String();
		Test.Assert(Json.Serialize(original, buffer) case .Ok, "Serialization failed");

		let restored = scope LabelSet();
		Test.Assert(Json.Deserialize<LabelSet>(buffer, restored) case .Ok, scope $"Deserialization failed for {buffer}");

		Test.Assert(restored.Labels[0] == "alpha", scope $"Expected Labels[0]='alpha', got '{restored.Labels[0]}'");
		Test.Assert(restored.Labels[1] == "beta", scope $"Expected Labels[1]='beta', got '{restored.Labels[1]}'");
		Test.Assert(restored.Labels[2] == "gamma", scope $"Expected Labels[2]='gamma', got '{restored.Labels[2]}'");
		Test.Assert(restored.Modes[0] == .Inactive, scope $"Expected Modes[0]=Inactive, got {restored.Modes[0]}");
		Test.Assert(restored.Modes[1] == .Banned, scope $"Expected Modes[1]=Banned, got {restored.Modes[1]}");

		Debug.WriteLine("Reflection: Sized Array Of Strings And Enums - PASSED");
	}

	[Test(Name = "Reflection: StringView Deserialize Overloads")]
	public static void T_StringViewDeserializeOverloads()
	{
		let json = """
			{"Description": "From text", "Value": 7}
			""";

		let filled = scope NestedInfo();
		Test.Assert(Json.Deserialize<NestedInfo>(json, filled) case .Ok, "Deserialize(StringView, T) failed");
		Test.Assert(filled.Description == "From text", scope $"Expected Description='From text', got '{filled.Description}'");
		Test.Assert(filled.Value == 7, scope $"Expected Value=7, got {filled.Value}");

		if (Json.Deserialize<NestedInfo>(json) case .Ok(let allocated))
		{
			defer delete allocated;
			Test.Assert(allocated.Description == "From text", scope $"Expected Description='From text', got '{allocated.Description}'");
			Test.Assert(allocated.Value == 7, scope $"Expected Value=7, got {allocated.Value}");
		}
		else
		{
			Test.Assert(false, "Deserialize<T>(StringView) failed");
		}

		Debug.WriteLine("Reflection: StringView Deserialize Overloads - PASSED");
	}
}

/// Base class for inheritance testing
[JsonObject]
class BaseClass
{
	public int BaseField;
}

/// Derived class with inherited fields
[JsonObject]
class DerivedClass : BaseClass
{
	public String DerivedField = new .() ~ delete _;
}

/// Test class with JsonRequired attribute
[JsonObject]
class RequiredFieldClass
{
	[JsonRequired]
	public String RequiredField = new .() ~ delete _;

	public String OptionalField = new .() ~ delete _;
}

/// Test class with JsonOptional attribute
[JsonObject]
class OptionalFieldClass
{
	[JsonRequired]
	public String RequiredField = new .() ~ delete _;

	[JsonOptional]
	public int OptionalField;
}

/// Test class with nested object that is optional by default
[JsonObject]
class ClassWithNestedObject
{
	public String Name = new .() ~ delete _;
	public int Value;
	public NestedInfo NestedObject;
}

/// Test class with required nested object
[JsonObject]
class ClassWithRequiredNested
{
	public String Name = new .() ~ delete _;

	[JsonRequired]
	public NestedInfo RequiredNested;
}

/// Test class with DefaultBehavior = Required - all fields required by default
[JsonObject(DefaultBehavior = .Required)]
class AllRequiredClass
{
	public String Name = new .() ~ delete _;
	public int Score;
	public int Level;
}

/// Test class with DefaultBehavior = Required but some fields marked [JsonOptional]
[JsonObject(DefaultBehavior = .Required)]
class MixedRequiredOptionalClass
{
	public String RequiredField = new .() ~ delete _;

	[JsonOptional]
	public int OptionalField;

	public int AnotherRequired;
}
