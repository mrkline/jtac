module par;

import std.process;
import std.conv : to;

void formatAndWriteWithPar(string toWrite, int width = 80)
{
	auto pipes = pipeProcess(["par", width.to!string], Redirect.stdin);
	scope(failure) kill(pipes.pid);
	scope(exit) wait(pipes.pid);

	pipes.stdin.write(toWrite);
	pipes.stdin.close();
}
