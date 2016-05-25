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
Usage: jtac --username <uname> --password <pass> <command> [<command args>]

JTAC is the JIRA Tooling and Automation CLI (and totally not a backronym).
Its goal is to automate some of the more trivial parts of a JIRA/Git workflow.

Options:

  --help, -h
    Display this help text.

  --version, -V
    Display version information.

  --verbose, -v
    Print extra info to stderr. Can be specified multiple times for more info.

    Verbosity levels are (roughly)
    1+: Print major actions (mostly JIRA server interactions) as they happen.
    2+: Print additional info (URLs being used for HTTP requests, etc.).
    3+: Print debug-level info (contents of HTTP POSTs, etc.).

  --username
    Your JIRA username

  --password
    Your JIRA password (See below for ways to provide this securely.)

All of the above options can also be set in a config file, which should
be saved as $XDG_CONFIG_HOME/jtacrc (usually ~/.config/jtacrc).
Each line in this file can specify an option with the following syntax:

  option = value

Only foolish users would place a password in plaintext file. To prevent such a
tragedy, options can be provided via a shell command surrounded by $( ).
For example, one could provide their password using secret-tool like so:

  password = $(secret-tool lookup <needed args>)


Commands:

  jtac issues
      List all issues assigned to you and not marked as Done.

  jtac show <issue>
      Show info for the given issue. Currently this only includes
      the last-modified time and the issue description.

  jtac transition <issue> [<transition to>]
      List the states the given issue can transition to, or perform a transition
      to the given state.

  jtac worked <date> [<time>] for <duration> on <issue>[: <comment>]
      Logs the given amount of time, starting at the given date and time,
      with an optional comment. If the time is not specified, 9 AM is assumed.
      Dates and times are generally specified in ISO 8601 formats,
      but JTAC tries to be liberal on what it accepts.
      Examples:

      jtac worked today for 2h on WUT-42: Did some work
      jtac worked yesterday, 23:30 for 3h 2m on WUT-22: Got it working!
      jtac worked 2016-05-25T1045 for 5m on WUT-6: Fixed the thing
      jtac worked 2016-05-24 11:45 for 5m on WUT-9: Harder, better, faster...
EOS";
