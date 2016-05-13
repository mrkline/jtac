module start;

import std.algorithm;
import std.array;
import std.exception;
import std.range;
import std.regex;
import std.stdio;
import std.uni : toLower;
import std.utf : byCodeUnit;

import stdx.data.json;

import jtac : verbosity;

import git;
import help;
import issues;
import rest : HTTPException;

void startIssue(string[] args)
{
	if (args.length < 3) writeAndFail("Usage: jtac start <issue>");

	immutable key = args[2];

	if (verbosity > 0) stderr.writeln("Requesting issue ", key, " from JIRA server");
	immutable issueJSON = getIssue(key);

	// If the issue isn't unstarted, warn the user, but try to proceed anyways.
	if (extractStatusCategory(issueJSON) != "new") {
		stderr.writeln("Warning: ", key, " is not an unstarted issue.");
	}

	// We're making the assumption that the JIRA workflow's first step is
	// "In progress"
	try {
		string inProgressID = getStateID(key, "In Progress");
		transitionToState(key, inProgressID);
		if (verbosity > 0) stderr.writeln(key, " state set to \"In Progress\"");
	}
	catch (HTTPException ex) {
		writeAndFail("Couldn't mark ", key, " as \"In Progress\" (HTTP ",
		             ex.statusLine.code, ")");
	}

    // Get the summary and make a name for it
    string branchName = "topics/" ~ // TODO: Don't hardcode prefix
		makeBranchNameFromSummary(extractSummary(issueJSON).summary);

	if (!isValidBranchName(branchName)) {
		stderr.writeln(
			"Warning: git check-ref-format isn't happy with the branch name",
			branchName, ".");
		stderr.writeln("Create a branch yourself.");
	}
	else if (!createBranch(branchName)) { // TODO: What if branch already exists?
		writeAndFail("git checkout -b ", branchName, " failed.");
	}

	if (verbosity > 0) stderr.writeln("Created branch ", branchName);
}

private:

string extractStatusCategory(const ref JSONValue issueJSON)
{
	immutable fields = getFields(issueJSON);

	// Check the current status category of the issue
	// (it should be new, i.e., unstarted)
	enforce("status" in fields &&
	        "statusCategory" in fields["status"] &&
	        "key" in fields["status"]["statusCategory"],
	        "Could not find issue status category");

	immutable statusCategoryKey = fields["status"]["statusCategory"]["key"];
	enforce(statusCategoryKey.hasType!string, "Issue status category key is not a string");

	return statusCategoryKey.get!string;
}

string makeBranchNameFromSummary(string summary)
{
	enum whitespaceSplitter = ctRegex!`\s+`;

	return summary
		.splitter(whitespaceSplitter) // Split into words
		.take(5) // Take the first five words
		.join("-")
		.toLower();
}