module jtac;

import std.conv;
import std.stdio;
import std.getopt;
import std.array : empty;

import stdx.data.json;

import auth;
import help;
import issues;
import rc;
import rest : HTTPException, printHTTPException;
import start;
import transition;
import worked;

// Make these guys global for easy access
shared uint verbosity;
shared string url;

int main(string[] args)
{
	string username;
	string password;
	// To suppress complaints about read-modify-write on the global shared variables,
	// parse config and args with locals, then assign to the globals above.
	string localUrl;
	uint localVerb;

	// Get anything in the jtacrc
	string[string] rcConfig = loadRC!"jtacrc"();

	// Check those for recognized arguments
	foreach (key, value; rcConfig) {
		switch(key) {
			case "username": username = value; break;
			case "password": password = value; break;
			case "url" : localUrl = value; break;
			case "verbose": {
				try { localVerb = value.to!uint; }
				catch (ConvException ce) {
					stderr.writeln("Couldn't convert \"", value, "\" to int");
				}
				break;
			}
			default: stderr.writeln("Unknown option \"", key, "\" in config"); break;
		}
	}

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
		// Tack on the API base point
		url = localUrl ~ "/rest/api/2/";
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

			case "transition":
			case "transitions": // Be forgiving
				transitionIssue(args);
				break;

			case "start":
				startIssue(args);
				break;

			case "worked":
				logWork(args);
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
