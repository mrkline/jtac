module jtac;

import std.stdio;
import std.getopt;
import std.array : empty;

import stdx.data.json;

import auth;
import help;
import issues;

int main(string[] args)
{
	int verbosity;
	string username;
	string password;
	string url;

	try {
		getopt(args, config.caseSensitive, config.bundling,
			"help|h", { writeAndSucceed(helpText); },
			"version|V", { writeAndSucceed(versionString); },
			"verbose|v+", &verbosity,
			"username|u", &username,
			"password|p", &password,
			"url", &url
			);
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

	printMyIssues(url);

	return 0;
}
