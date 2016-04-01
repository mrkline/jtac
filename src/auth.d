/**
 * Authentication utilities for JIRA's REST API.
 *
 * JIRA's API offeres a few authentication methods:
 * 1. OAuth
 * 2. Cookies
 * 3. "Basic"
 *
 * Approach 1 requires admin cooperation, 2 didn't seem to be working, so we're
 * settling with 3. "Basic" authentication involves base64 encoding the
 * user:password pair and sending it in a header with each request.
 * This isn't the best, but assuming you're using HTTPS we sould be fine.
 */
module auth;

import std.array : empty;
import std.base64;
import std.exception : enforce;
import std.range;
import std.utf;

/// A global shared instance of the authentication string.
/// Have a single global instance.
/// (This is a step away from plaintext passswords,
/// so the least we can do is not have a bunch of instances of it.)
shared string authString;

/// Cache the header string while we're at it so we don't have to keep
/// concatenating it together.
string[string] authHeader;

string createAuthString(string username, string password)
{
	// re: byCodeUnit:
	// http://forum.dlang.org/post/dzphvwkxevlqwwiusfvh@forum.dlang.org
	authString = Base64.encode(chain(username.byCodeUnit,
	                                 ":".byCodeUnit,
	                                 password.byCodeUnit));
	authHeader = ["Authorization" : "Basic " ~ authString];
	return authString;
}
