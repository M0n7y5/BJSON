using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

/// A user in the system
[JsonObject]
class User
{
	/// The user's unique identifier
	[JsonRequired]
	[JsonPropertyName("id")]
	public int64 Id;

	/// The user's email address
	[JsonRequired]
	[JsonPropertyName("email")]
	public String Email = new .() ~ delete _;

	/// The user's display name
	[JsonPropertyName("name")]
	public String Name = new .() ~ delete _;

	/// The user's age in years
	[JsonPropertyName("age")]
	public int64? Age;

	/// Whether the account is active
	[JsonPropertyName("is_active")]
	public bool IsActive;

}
