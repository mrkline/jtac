/// Commands for getting issue information
module issues;

import std.algorithm;
import std.conv : to;
import std.datetime;
import std.exception : enforce;
import std.stdio;

import stdx.data.json;

import jtac : url;

import auth;
import help;
import par;
import rest;

void printMyIssues(string[] args)
{
	auto issues = getIssuesSummary(url);

	writeln("My issues:");
	foreach (ref issue; issues) {
		write("\t");
		writeIssueSummaryLine(issue);
	}
}

void printIssue(string[] args)
{
	import std.array : replaceFirst;

	if (args.length < 3) writeAndFail("Usage: jtac show <issue>");

	immutable issueJSON = getIssue(url, args[2]);
	immutable summary = extractSummary(issueJSON);
	immutable fields = getFields(issueJSON);
	immutable description = extractDescription(fields);

	writeIssueSummaryLine(summary);
	writeln();

	const DateTime dt = extractDate(fields).toLocalTime().to!DateTime;
	writeln("Last updated ", dt.toISOExtString().replaceFirst("T", ", "));
	writeln();

	formatAndWriteWithPar(description);
}

private:

JSONValue getFields(const ref JSONValue val)
{
	enforce("fields" in val, "Could not find issue fields");
	return val["fields"];
}

string extractDescription(const ref JSONValue fields)
{
	enforce("description" in fields, "Could not find issue description");
	return fields["description"].get!string;
}

auto extractDate(const ref JSONValue fields)
{
	import std.array : insertInPlace;

	enforce("updated" in fields, "Could not find issue date");
	string date = fields["updated"].get!string;
	//fromISOExtString expects a colon in the time zone field.
	date.insertInPlace(date.length - 2, ":");
	return SysTime.fromISOExtString(date);
}

struct IssueSummary {
	string key;
	string summary;
	string status;
};

void writeIssueSummaryLine(const ref IssueSummary summ)
{
	writeln(summ.key, ": ", summ.summary, " (", summ.status, ")");
}

IssueSummary extractSummary(const ref JSONValue val)
{
	IssueSummary ret;

	enforce("key" in val, "Could not find issue key");

	ret.key = val["key"].get!string;

	const JSONValue fields = getFields(val);

	enforce("summary" in fields, "Could not find issue summary");
	enforce("status" in fields && "name" in fields["status"], "Could not find issue status");

	ret.summary = fields["summary"].get!string;
	ret.status = fields["status"]["name"].get!string;

	return ret;
}

auto getIssuesSummary(string url)
{
	string testQuery = `{
		"jql" : "assignee = currentUser() AND status != Done ORDER BY updatedDate DESC",
		"validateQuery" : true,
		"fields" : ["summary", "status"]
	}`;

	auto issues = post(url ~ "/rest/api/2/search", testQuery, authHeader)["issues"];

	enforce(issues.hasType!(JSONValue[]), ".issues isn't an array of the issues");

	return issues.get!(JSONValue[]).map!(v => extractSummary(v));
}

auto getIssue(string url, string key)
{
	return get(url ~ "/rest/api/2/issue/" ~ key, authHeader);
}
