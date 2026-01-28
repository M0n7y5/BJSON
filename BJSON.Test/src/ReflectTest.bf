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
	// Basic types
	public String Name = new .() ~ delete _;
	public int Health;
	public float Speed;
	public bool IsAlive;

	// Custom property name
	[JsonPropertyName("player_level")]
	public int Level;

	// Nullable field
	public int? OptionalScore;

	// Enum field
	public PlayerStatus Status;

	// Nested object (pre-allocated)
	public NestedInfo Info = new .() ~ delete _;

	// List of primitives
	public List<int> Scores = new .() ~ delete _;

	// List of strings (each item will be heap allocated)
	public List<String> Tags = new .() ~ DeleteContainerAndItems!(_);

	// Dictionary with string keys
	public Dictionary<String, int> Stats = new .() ~ DeleteDictionaryAndKeys!(_);

	// Ignored field
	[JsonIgnore(Condition = .Always)]
	public int InternalId;

	// Sized array
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

		// Verify basic fields
		Test.Assert(player.Name == "TestPlayer", scope $"Expected 'TestPlayer', got '{player.Name}'");
		Test.Assert(player.Health == 100, scope $"Expected Health=100, got {player.Health}");
		Test.Assert(Math.Abs(player.Speed - 5.5f) < 0.01f, scope $"Expected Speed=5.5, got {player.Speed}");
		Test.Assert(player.IsAlive == true, "Expected IsAlive=true");
		Test.Assert(player.Level == 42, scope $"Expected Level=42, got {player.Level}");

		// Verify enum
		Test.Assert(player.Status == .Active, scope $"Expected Status=Active, got {player.Status}");

		// Verify nested object
		Test.Assert(player.Info.Description == "A test player", scope $"Expected Info.Description='A test player', got '{player.Info.Description}'");
		Test.Assert(player.Info.Value == 999, scope $"Expected Info.Value=999, got {player.Info.Value}");

		// Verify list of ints
		Test.Assert(player.Scores.Count == 3, scope $"Expected 3 scores, got {player.Scores.Count}");
		Test.Assert(player.Scores[0] == 10 && player.Scores[1] == 20 && player.Scores[2] == 30, "Scores mismatch");

		// Verify list of strings
		Test.Assert(player.Tags.Count == 2, scope $"Expected 2 tags, got {player.Tags.Count}");
		Test.Assert(player.Tags[0] == "warrior", scope $"Expected first tag 'warrior', got '{player.Tags[0]}'");

		// Verify dictionary
		Test.Assert(player.Stats.Count == 2, scope $"Expected 2 stats, got {player.Stats.Count}");
		Test.Assert(player.Stats.ContainsKeyAlt("strength"), "Missing 'strength' stat");
		if (player.Stats.TryGetValueAlt("strength", let strengthVal))
			Test.Assert(strengthVal == 10, "Wrong strength value");

		// Verify sized array
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

		// Parse the result back and verify
		var parseResult = Json.Deserialize(buffer);
		defer parseResult.Dispose();

		Test.Assert(parseResult case .Ok, scope $"Failed to parse serialized JSON: {buffer}");

		let root = parseResult.Value.AsObject().Value;
		Test.Assert((StringView)root.GetValue("Name").Value == "SerializeTest", "Name mismatch");
		Test.Assert((int)root.GetValue("Health").Value == 75, "Health mismatch");
		Test.Assert(root.GetValue("IsAlive").Value == false, "IsAlive mismatch");

		// Check custom property name was used
		Test.Assert(root.ContainsKey("player_level"), "Custom property name 'player_level' not found");
		Test.Assert((int)root.GetValue("player_level").Value == 10, "Level mismatch");

		// Check ignored field is not present
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

		// Serialize
		let buffer = scope String();
		Test.Assert(Json.Serialize(original, buffer) case .Ok, "Serialization failed");

		// Parse and deserialize into new object using the new stream API
		let stream = scope StringStream(buffer, .Reference);
		let restored = scope Player();
		Test.Assert(Json.Deserialize<Player>(stream, restored) case .Ok, "Deserialization failed");

		// Compare
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
		// Test with optional field present
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

		// Test without optional field
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
		player2.OptionalScore = null; // Ensure it starts as null
		Test.Assert(player2.JsonDeserialize(result2.Value) case .Ok, "Deserialize failed");
		// OptionalScore should remain null since it wasn't in JSON

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

		// Test serialization includes private field
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
		// Missing required field "Health"
		let json = """
			{
				"Name": "Test",
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
		Test.Assert(deserializeResult case .Err, "Should fail on missing required field 'Health'");

		Debug.WriteLine("Reflection: Error on Missing Required Field - PASSED");
	}

	[Test(Name = "Reflection: Error on Type Mismatch")]
	public static void T_ErrorOnTypeMismatch()
	{
		// Health should be number, not string
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
		Test.Assert(deserializeResult case .Err, "Should fail on type mismatch for 'Health'");

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

		// Verify the output is valid JSON by parsing it
		var parseResult = Json.Deserialize(buffer);
		defer parseResult.Dispose();
		Test.Assert(parseResult case .Ok, scope $"Failed to parse serialized JSON with escapes: {buffer}");

		// Verify the string was properly escaped and unescaped
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

		// Use the allocating API - returns a new object
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

		// Serialize directly to a MemoryStream
		let memStream = scope MemoryStream();
		Test.Assert(Json.Serialize(info, memStream) case .Ok, "Stream serialization failed");

		// Read back the stream contents
		memStream.Position = 0;
		let buffer = scope String();
		let len = (int)memStream.Length;
		buffer.Reserve(len);
		for (int i = 0; i < len; i++)
		{
			if (memStream.Read<char8>() case .Ok(let c))
				buffer.Append(c);
		}

		// Verify the JSON is correct
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
		// Test that inherited fields are serialized/deserialized
		let derived = scope DerivedClass();
		derived.BaseField = 42;
		derived.DerivedField.Set("test");

		let buffer = scope String();
		Test.Assert(Json.Serialize(derived, buffer) case .Ok, "Serialization failed");

		// Debug output
		Debug.WriteLine(scope $"Serialized JSON: {buffer}");

		// Verify both base and derived fields are in JSON
		Test.Assert(buffer.Contains("BaseField"), scope $"Base field not serialized. JSON: {buffer}");
		Test.Assert(buffer.Contains("DerivedField"), scope $"Derived field not serialized. JSON: {buffer}");

		// Deserialize
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

		// Verify both fields were restored
		Test.Assert(restored.BaseField == 100, scope $"BaseField mismatch: {restored.BaseField}");
		Test.Assert(restored.DerivedField == "restored", scope $"DerivedField mismatch: {restored.DerivedField}");

		Debug.WriteLine("Reflection: Inheritance - PASSED");
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
