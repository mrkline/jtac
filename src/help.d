import std.stdio;
import core.stdc.stdlib : exit;

/// Writes whatever you tell it and then exits the program successfully
void writeAndSucceed(S...)(S toWrite)
{
    writeln(toWrite);
    exit(0);
}

/// Writes the help text and fails.
/// If the user explicitly requests help, we'll succeed (see writeAndSucceed),
/// but if what they give us isn't valid, bail.
void writeAndFail(S...)(S helpText)
{
    stderr.writeln(helpText);
    exit(1);
}

string versionString = q"EOS
jtac v0.1 by Matt Kline, Fluke Networks
EOS";

string helpText = q"EOS
Usage: jtac <subcommand> [<subcommand args>]

jtac is JIRA Tooling and Automation CLI (and totally not a backronym).
Its goal is to automate some of the more trivial parts of a JIRA/Git workflow.

Verbosity levels are (roughly)
1+: Print major actions (mostly JIRA server interactions) as they are performed
2+: Print additional info (URLs being used for HTTP requests, etc.)
3+: Print debug-level info (contents of HTTP POSTs, etc.)
EOS";
