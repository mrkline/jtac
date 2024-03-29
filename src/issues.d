/// Commands for getting issue information,
/// and plumbing for pulling useful info out of JIRA's JSON responses.
module issues;

import std.algorithm;
import std.array : empty;
import std.conv : to;
import std.datetime;
import std.exception : enforce;
import std.stdio;

import stdx.data.json;

import jtac : url, verbosity;

import auth;
import conversion;
import help;
import par;
import rest;

/// Top-level command: Get issues and write out their one-line summaries
void printMyIssues(string[] args)
{
	if (verbosity > 0) stderr.writeln("Requesting the user's issues from JIRA server");
	auto issues = getIssuesSummary();

	writeln("My issues:");
	foreach (ref issue; issues) {
		write("\t");
		writeIssueSummaryLine(issue);
	}
}

/// Top-level command: Get an issue and write its summary, update time,
/// and description
void printIssue(string[] args)
{
	if (args.length < 3) writeAndFail("Usage: jtac show <issue>");

	immutable key = args[2];

	if (verbosity > 0) stderr.writeln("Requesting issue ", key, " from JIRA server");
	immutable issueJSON = getIssue(key);
	immutable summary = extractSummary(issueJSON);
	immutable fields = getFields(issueJSON);

	writeIssueSummaryLine(summary);
	writeln();

	immutable DateTime dt = extractDate(fields).toLocalTime().to!DateTime;
	writeln("Last updated ", dt.toPrintedTime());
	writeln();

	if (verbosity > 0) stderr.writeln("Formatting issue description using par");
	immutable description = extractDescription(fields);
	formatAndWriteWithPar(description);
}

/// The JSON returned by the endpoint "issue/<id>" holds most info in a "fields"
/// ...field.
JSONValue getFields(const ref JSONValue val)
{
	enforce("fields" in val, "Could not find issue fields");
	return val["fields"];
}

/// Pulls the description of an issue from its fields
string extractDescription(const ref JSONValue fields)
{
	enforce("description" in fields, "Could not find issue description");
	return fields["description"].get!string;
}

/// Pulls the "last updated" date out of an issue from its fields
auto extractDate(const ref JSONValue fields)
{
	enforce("updated" in fields, "Could not find issue date");
	string date = fields["updated"].get!string;
	return fromJIRATime(date);
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

// Extracts an issues's summary (key, summary, and status) from its JSON
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

/// Returns a range of issue summaries for all a users' issues that aren't Done
auto getIssuesSummary()
{
	string testQuery = `{
		"jql" : "assignee = currentUser() AND status != Done ORDER BY updatedDate DESC",
		"validateQuery" : true,
		"fields" : ["summary", "status"]
	}`;

	auto issues = post(url ~ "search", testQuery, authHeader)["issues"];

	enforce(issues.hasType!(JSONValue[]), ".issues isn't an array of the issues");

	return issues.get!(JSONValue[]).map!(v => extractSummary(v));
}

/// Returns the JSON for a given issue
auto getIssue(string key)
{
	return get(url ~ "issue/" ~ key, authHeader);
}

/// Returns the JSON array of transitions for a given issue
auto getIssueTransitions(string key)
{
	// The "transitions" endpoint lists the transitions for an issue
	auto result = get(url ~ "issue/" ~ key ~ "/transitions", authHeader);
	enforce("transitions" in result);

	auto transitions = result["transitions"];
	enforce(transitions.hasType!(JSONValue[]),
	        ".transitions isn't an array of transitions");
	return transitions.get!(JSONValue[]);
}

/// Extracts a state's name from its JSON
string extractStateName(const ref JSONValue state)
{
	enforce("name" in state, "Couldn't extract a state's name");
	return state["name"].get!string;
}

/// Iterates through all transitions, finding the ID of the first with the given name.
/// These IDs seem to be numeric, but are strings. Screwy.
string getTransitionID(const(JSONValue)[] transitions, string stateName)
{
	transitions = transitions.find!(j => extractStateName(j) == stateName);

	// Return an empty string if we didn't find it
	if (transitions.empty) return "";

	enforce("id" in transitions[0]);
	return transitions[0]["id"].get!string;
}

/// Given an issue and a transition ID, make that transition.
void transitionTo(string key, string transitionID)
{
	string toPost = `{ "transition" : { "id" : "` ~ transitionID ~ `" }}`;

	auto result = post(url ~ "issue/" ~ key ~ "/transitions", toPost, authHeader);
}
