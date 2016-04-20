import std.algorithm;
import std.conv : to;
import std.exception : enforce;
import std.stdio;

import stdx.data.json;

import auth;
import rest;

void printMyIssues(string url)
{
	auto issues = getIssuesSummary(url);

	writeln("My issues:");
	foreach (issue; issues) {
		writeln("\t", issue.key, ": ", issue.summary, " (", issue.status, ")");
	}


}

private:

struct IssueSummary {
	string key;
	string summary;
	string status;
};

IssueSummary extractSummary(const ref JSONValue val)
{
	IssueSummary ret;

	enforce("key" in val, "Could not find issue key");

	ret.key = val["key"].get!string;

	enforce("fields" in val, "Could not find issue fields");

	const JSONValue fields = val["fields"];

	enforce("summary" in fields, "Could not find issue summary");
	enforce("status" in fields && "name" in fields["status"], "Could not find issue status");

	ret.summary = fields["summary"].get!string;
	ret.status = fields["status"]["name"].get!string;

	return ret;
}

auto getIssuesSummary(string url)
{
	// What's idiomatic use here?
	// Could construct from a string (like so) or use AA
	// (which requires spraying the constructor everywhere).
	// Would be nice if we could parse this at compile time, but get all sorts
	// of nasty taggedalgebraiec errors.
	JSONValue testQuery = `{
		"jql" : "assignee = currentUser() AND status != Done ORDER BY updatedDate DESC",
		"validateQuery" : true,
		"fields" : ["summary", "status"]
	}`.toJSONValue();

	auto issues = post(url ~ "/rest/api/2/search", testQuery, authHeader)["issues"];

	enforce(issues.hasType!(JSONValue[]), ".issues isn't an array of the issues");

	return issues.get!(JSONValue[]).map!(v => extractSummary(v));
}
