module git;

import std.exception : enforce;
import std.process;

bool isInRepo()
{
	return execute(["git", "status"]).status == 0;
}

void enforceInRepo()
{
	enforce(isInRepo(), "The current directory is not in a Git repository.");
}

bool isValidBranchName(string name)
{
	return execute(["git", "check-ref-format", name]).status == 0;
}

bool createBranch(string name)
{
	auto pid = spawnProcess(["git", "checkout", "-b", name]);
	return wait(pid) == 0;
}
