# JTAC

JTAC: The JIRA Tooling and Automation CLI (and totally not a backronym)

Its goal is to automate some of the more trivial parts of a JIRA/Git workflow,
and make a few common tasks possible via command line.

## Requirements

1. A [D](http://dlang.org) toolchain

2. [Dub](https://code.dlang.org/getting_started)

3. [par](https://en.wikipedia.org/wiki/Par_\(command\))
   (used for formatting, and usually available through your package manager)

## How do I build it?

1. [Get a D compiler.](http://dlang.org/download.html)

2. Get Dub. (See <https://code.dlang.org/download> for download options.
   Arch, Debian, Homebrew, and MacPorts packages are available.)

3. Run `dub build` or `dub build -b release`

## How do I run it?

See `jtac --help` for usage info. If you want to read it before building, see
`src/help.d`

## What does it do?

### Currently supported

- List all unfinished JIRA issues
- List an issue summary (name, status, last-modified, description)
- Transition an issue to a different state

### Planned

- Automatically create and checkout a branch when starting an issue.
- Pull request integration(?)
- \<Your desired features here. Ping Matt Kline\>

(Some of these will be useless if/when we ever get JIRA/Stash integration, but
until then...)

## Why D, as opposed to Python, Ruby, \<other more common dynamic language here\>?

I like D because it provides most of the flexibility of these languages,
and compile-time type checking and native performance are cool.

![You come to me at runtime to tell me the code you are executing does not compile.](http://i.imgur.com/OsVN8P5.png)
