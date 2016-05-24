module transition;

import std.algorithm;
import std.array : empty;
import std.conv : to;
import std.stdio;

import stdx.data.json;

import jtac : verbosity;

import help;
import issues;

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
		if (verbosity > 0) stderr.writeln("Requesting issue ", key, " from JIRA server");
		immutable issueJSON = getIssue(key);
		immutable summary = extractSummary(issueJSON);

		writeIssueSummaryLine(summary);

		if (verbosity > 0) stderr.writeln("Requesting possible transition states from JIRA server");
		const JSONValue[] transitionsJSON = getIssueTransitions(key);

		writeln("can transition to:");
		foreach (state; transitionsJSON.map!(j => extractStateName(j))) {
			writeln("\t", state);
		}
	}
	else {
		// Join subsequent args together to handle a case where the state name
		// has spaces and the user didn't enclose it in quotes
		string to = joiner(args[3 .. $], " ").to!string;

		// We have to get all issues and look up which one has the given name
		// (via getTransitionID) before passing that ID to transitionToState.
		if (verbosity > 0) stderr.writeln("Querying server for issue transition named \"", to, '"');
		string id = getTransitionID(getIssueTransitions(key), to);

		if (id.empty) writeAndFail("Couldn't find tansition named \"", to);

		if (verbosity > 0) stderr.writeln("Attempting to transition issue");
		transitionTo(key, id);
	}
}
