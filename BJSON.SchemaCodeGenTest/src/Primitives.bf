using System;
using System.Collections;
using BJSON.Attributes;
using BJSON.Models;

namespace BJSON.SchemaCodeGenTest;

/// A user in the system
[JsonObject]
class Primitives
{
	/// The user's unique identifier
	[JsonRequired]
	public int64 Id;

	/// The user's email address
	[JsonRequired]
	public String Email = new .() ~ delete _;

	/// The user's display name
	public String Name = new .() ~ delete _;

	/// The user's age in years
	public int64? Age;

	/// Whether the account is active
	[JsonPropertyName("is_active")]
	public bool IsActive;

}
