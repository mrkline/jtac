module jtac;

import std.stdio;
import std.getopt;
import std.array : empty;

import stdx.data.json;

import auth;
import help;
import issues;
import rest : HTTPException, printHTTPException;

// Make these guys global for easy access
shared int verbosity;
shared string url;

int main(string[] args)
{
	string username;
	string password;
	// To suppress complaints about read-modify-write on the global shared variables:
	int localVerb;
	string localUrl;

	try {
		getopt(args, config.caseSensitive, config.bundling,
			"help|h", { writeAndSucceed(helpText); },
			"version|V", { writeAndSucceed(versionString); },
			"verbose|v+", &localVerb,
			"username|u", &username,
			"password|p", &password,
			"url", &localUrl
			);
		verbosity = localVerb;
		url = localUrl;
	}
	catch (GetOptException ex) {
		writeAndFail(ex.msg, "\n\n", helpText);
	}

	if (username.empty || password.empty) {
		writeAndFail("username and password required");
	}

	if (url.empty) {
		writeAndFail("Base URL required");
	}

	createAuthString(username, password);

	if (args.length < 2) writeAndFail(helpText);

	try {
		switch(args[1]) {
			case "issues":
				printMyIssues(args);
				break;

			case "show":
				printIssue(args);
				break;

			default:
				writeAndFail(helpText);
		}
	}
	catch (HTTPException ex) {
		printHTTPException(ex);
		return 1;
	}

	return 0;
}
