/// Commands for getting issue information
module issues;

import std.algorithm;
import std.array : empty;
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

/// Top-level command: Get issues and write out their one-line summaries
void printMyIssues(string[] args)
{
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
	import std.array : replaceFirst;

	if (args.length < 3) writeAndFail("Usage: jtac show <issue>");

	immutable key = args[2];

	immutable issueJSON = getIssue(key);
	immutable summary = extractSummary(issueJSON);
	immutable fields = getFields(issueJSON);

	writeIssueSummaryLine(summary);
	writeln();

	immutable DateTime dt = extractDate(fields).toLocalTime().to!DateTime;
	writeln("Last updated ", dt.toISOExtString().replaceFirst("T", ", "));
	writeln();

	immutable description = extractDescription(fields);
	formatAndWriteWithPar(description);
}

/// Top-level command: Show states an issue can transition to,
/// or perform one of these transitions.
void transitionIssue(string[] args)
{
	if (args.length < 3) {
		writeAndFail("Usage: jtac transition <issue> [<transition to>]");
	}

	immutable key = args[2];

	// If the user didn't specify anything to transition to,
	// list possible transitions.
	if (args.length == 3) {
		immutable issueJSON = getIssue(key);
		immutable summary = extractSummary(issueJSON);

		writeIssueSummaryLine(summary);

		const JSONValue[] statesJSON = getIssueStates(key);

		writeln("can transition to:");
		foreach (state; statesJSON.map!(j => extractStateName(j))) {
			writeln("\t", state);
		}
	}
	else {
		// Join subsequent args together to handle a case where the state name
		// has spaces and the user didn't enclose it in quotes
		string toState = joiner(args[3 .. $], " ").to!string;

		// We have to get all issues and look up which one has the given name
		// (via getStateID) before passing that ID to transitionToState.
		transitionToState(key, getStateID(key, toState));
	}
}

private:

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

/// Returns the JSON array of states for a given issue
auto getIssueStates(string key)
{
	// The "transitions" endpoint lists the states an issue can transition *to*,
	// not the transitions themselves. Boo, Atlassian.
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

/// Iterates through all states, finding the ID of the first with the given name.
/// These IDs seem to be numeric, but are strings. Screwy.
string getStateID(string key, string stateName)
{

	const(JSONValue)[] states = getIssueStates(key);

	states = states.find!(j => extractStateName(j) == stateName);
	if (states.empty) writeAndFail("Couldn't find state with name ", stateName);

	enforce("id" in states[0]);
	return states[0]["id"].get!string;
}

/// Given an issue and a stateID, transition to that state
void transitionToState(string key, string stateID)
{
	string toPost = `{ "transition" : { "id" : "` ~ stateID ~ `" }}`;

	auto result = post(url ~ "issue/" ~ key ~ "/transitions", toPost, authHeader);
}
