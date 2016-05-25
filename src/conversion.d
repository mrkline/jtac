module conversion;

import std.format;
import std.datetime;

/**
 * Put gently, the JIRA REST API is... peculiar and picky about time strings.
 * It's *almost* ISO 8601, but ever so slightly different.
 * For example, it throws a fit if there is no fractional seconds, even if
 * that fraction is 0.
 * It also demands time zone offsets in the form "[+-]hhmm" instead of the ISO
 * "[+-]hh:mm".
 * Even worse, instead of telling us this nicely, it often issues an HTTP 500.
 * (See https://jira.atlassian.com/browse/JRA-41379).
 *
 * The unfortunate consequence of all this is that we have to reimplement most
 * of D's SysTime.toISOExtString() to make JIRA happy.
 */

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
	// Implementation of the standard library's toISOExtString, with JIRA-needed
	// peculiarities.
	// See the comment at the top of the file for the whole sob story.

	immutable adjustedTime = st.timezone.utcToTZ(st.stdTime);
	long hnsecs = adjustedTime;

	auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

	if (hnsecs < 0)
	{
		hnsecs += convert!("hours", "hnsecs")(24);
		--days;
	}

	auto hour = splitUnitsFromHNSecs!"hours"(hnsecs);
	auto minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
	auto second = splitUnitsFromHNSecs!"seconds"(hnsecs);

	auto dateTime = DateTime(Date(cast(int)days), TimeOfDay(cast(int)hour, cast(int)minute, cast(int)second));
	auto fracSecStr = fracSeconds(cast(int)hnsecs);

	if (st.timezone is UTC())
		return dateTime.toISOExtString() ~ fracSeconds(cast(int)hnsecs) ~ "Z";

	// Always specify non-UTC timezone to keep JIRA happy.

	immutable utcOffset = dur!"hnsecs"(adjustedTime - st.stdTime);

	string tzOffset = getTzOffsetString(utcOffset);

	return format("%s%s%s",
	              dateTime.toISOExtString(),
	              fracSeconds(cast(int)hnsecs),
	              tzOffset);
}

/// Format times for printing.
string toPrintedTime(DateTime dt)
{
	import std.array : replaceFirst;

	// You get an ISO 8601 and a 24-hour time.
	return dt.toISOExtString().replaceFirst("T", ", ");
}

/*
unittest
{
	// Quick and dirty smoke test
	immutable now = Clock.currTime();
	string stringified = toJIRATime(now);
	immutable bar = fromJIRATime(stringified);
	assert(now == bar);
}
*/

private:

/// Like the standard library, but keep at least one digit to make JIRA happy.
string fracSeconds(int hnsecs)
{
	import std.array : popBack;

	string ret = format(".%07d", hnsecs);

	while (ret[$ - 1] == '0' && ret.length > 2)
		ret.popBack();

	return ret;
}

// Private function lifted straight out of std.datetime
long splitUnitsFromHNSecs(string units)(ref long hnsecs) @safe pure nothrow
    if (validTimeUnits(units) &&
       CmpTimeUnits!(units, "months") < 0)
{
    immutable value = convert!("hnsecs", units)(hnsecs);
    hnsecs -= convert!(units, "hnsecs")(value);

    return value;
}

static string getTzOffsetString(Duration utcOffset) @safe pure
{
	import std.exception;

	immutable absOffset = abs(utcOffset);
	enforce!DateTimeException(absOffset < dur!"minutes"(1440),
	                          "Offset from UTC must be within range (-24:00 - 24:00).");
	int hours;
	int minutes;
	absOffset.split!("hours", "minutes")(hours, minutes);

	// No colon (unlike the ISO standard) to keep JIRA happy.
	return format(utcOffset < Duration.zero ? "-%02d%02d" : "+%02d%02d", hours, minutes);
}
