module conversion;

import std.datetime;

SysTime fromJIRATime(string date)
{
	import std.regex;

	// fromISOExtString expects a colon in the time zone field,
	// and JIRA does not have it
	enum timeZonePortion = ctRegex!(`([+-])(\d{2})(\d{2})$`);

	// replace +HHMM time zone offset with +HH:MM
	date = date.replaceFirst(timeZonePortion, "$1$2:$3");

	return SysTime.fromISOExtString(date);
}

string toJIRATime(SysTime st)
{
	import std.regex;

	string ret = st.toISOExtString();

	// See above
	enum timeZonePortion = ctRegex!(`([+-])(\d{2}):(\d{2})$`);

	// replace +HH:MM time zone offset with +HHMM
	return ret.replaceFirst(timeZonePortion, "$1$2$3");
}

/// Format times for printing.
string toPrintedTime(DateTime dt)
{
	import std.array : replaceFirst;

	// You get an ISO 8601 and a 24-hour time.
	return dt.toISOExtString().replaceFirst("T", ", ");
}

unittest
{
	// Quick and dirty smoke test
	immutable now = Clock.currTime();
	string stringified = toJIRATime(now);
	immutable bar = fromJIRATime(stringified);
	assert(now == bar);
}
