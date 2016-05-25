module worked;

import std.algorithm : joiner;
import std.array : empty;
import std.conv;
import std.datetime;
import std.regex;

import stdx.data.json;

import jtac : url, verbosity;

import auth;
import conversion;
import help;
import rest;

void logWork(string[] args)
{
	import std.stdio;

	WorkEvent we = parseSentence(joiner(args[2 .. $], " ").to!string);

	// For debugging; the POST below is getting an HTTP 500 back.
	writeln(toJSON(get(url ~ "issue/" ~ we.key ~ "/worklog", authHeader)));

	JSONValue toPost = [
		"started" : JSONValue(toJIRATime(SysTime(we.when))), // Use the local time zone.
		"timeSpent" : JSONValue(we.duration)
		];
	if (!we.description.empty) {
		toPost["comment"] = JSONValue(we.description);
	}

	post(url ~ "issue/" ~ we.key ~ "/worklog", toPost, authHeader);
}

private:

struct WorkEvent {
	DateTime when;
	string duration;
	string key;
	string description;
}

WorkEvent parseSentence(string sentence)
{
	enum re = ctRegex!(`^\s*(.+)\s+for\s+(.+)\s+on\s+(\S+)(?::\s+(.+))?\s*$`);

	auto matches = sentence.matchFirst(re);

	if (!matches) {
		writeAndFail("Usage: jtac worked <date/time> for <duration> on <issue>");
	}

	WorkEvent ret;
	ret.when = parseWhen(matches[1]);
	ret.duration = matches[2];
	ret.key = matches[3];
	ret.description = matches[4];

	return ret;
}

DateTime parseWhen(string when)
{
	// Accept <yesterday/today/tomorrow/ISO date><separator><time>,
	// where <separator> is T or a comma with optional trailing spaces,
	// and <time> is hh:mm or hhmm.
	enum re = ctRegex!(`^(yesterday|today|tomorrow|(?:\d{4}-\d{2}-\d{2}))` ~ // date
	                   `(?:(?:,?\s*|T)(\d{2}:?\d{2}))?$`); // optional separator and time

	auto matches = when.matchFirst(re);

	if (!matches) writeAndFail("Couldn't make sense of date/time:", when);

	string dateString = matches[1];

	Date d;

	switch (dateString) {
		case "today":
			d = Clock.currTime().to!Date;
			break;

		case "tomorrow":
			d = Clock.currTime().to!Date + dur!"days"(1);
			break;

		case "yesterday":
			d = Clock.currTime().to!Date - dur!"days"(1);
			break;

		default:
			d = Date.fromISOExtString(dateString);
	}

	TimeOfDay t;

	if (!matches[2].empty) { // A time was given

		// We're assuming both hour and minute are two digits long,
		// optionally separated by a colon
		// (This is given in the regex above.)
		string hourAndMinute = matches[2];
		int hour = hourAndMinute[0 .. 2].to!int;
		int minute = hourAndMinute[$-2 .. $].to!int;
		t = TimeOfDay(hour, minute);
	}
	else {
		// Default to 9 AM.
		// TODO: Make this configurable?
		t = TimeOfDay(9, 0);
	}

	auto ret = DateTime(d, t);

	// We need at least one Easter egg, don't we?
	if (Clock.currTime().to!DateTime < ret) writeAndFail("Are you a wizard?");

	return DateTime(d, t);
}
