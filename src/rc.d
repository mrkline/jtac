module rc;

import std.file;
import std.path : buildPath, expandTilde;
import std.process : environment;
import std.regex;
import std.stdio;
import std.string;

string[string] loadRC(string configFileName)()
{
	string rcLocation = buildPath(
		environment.get("XDG_CONFIG_HOME", expandTilde("~/.config")),
		configFileName);

	string[string] ret;

	if (!exists(rcLocation)) return ret;
	if (!isFile(rcLocation)) {
		stderr.writeln(rcLocation, " exists but is not a file(??)");
		return ret;
	}

	// Each config line should be "key = value", or "key = $(shell stuff)"
	enum lineRegex = ctRegex!(`^\s*(\S+)\s*=\s*(.+)\s*$`);

	try {
		auto f = File(rcLocation, "r");
		foreach (line; f.byLine) {
			auto match = matchFirst(line, lineRegex);
			if (!match) {
				stderr.writeln("Couldn't make sense of config line ", line);
				continue;
			}

			string key = match[1].idup;
			string value = match[2].idup;

			// Run values that look like $(something) through the shell
			if (value.startsWith("$(")) {
				// Someone probably screwed up
				if (!value.endsWith(")")) {
					stderr.writeln("Config value ", key,
					               " starts with $( but doesn't end with ). Skipping.");
					continue;
				}

				string shelledValue = expandShellValue(value[2 .. $-1]);
				if (shelledValue.empty) {
					stderr.writeln("Config line ", line, " failed. Skipping.");
					continue;
				}
				ret[key] = shelledValue;
			}
			else {
				if (value.startsWith('"') && value.endsWith('"')) {
					value = value[1 .. $-1];
				}
				ret[key] = value;
			}
		}
	}
	catch (FileException fe) {
		stderr.writeln("Trouble reading ", rcLocation, ": ", fe.msg);
	}

	return ret;
}

private:

string expandShellValue(const(char)[] value)
{
	import std.process;

	immutable result = executeShell(value);
	if (result.status != 0) return "";
	else return result.output.strip();
}
