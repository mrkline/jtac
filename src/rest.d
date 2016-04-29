/// Basic facilities for interacting with JIRA's REST API
module rest;

import std.net.curl;

import stdx.data.json;

/// Builds URL parameter lists from the given key -> value pairs
string buildURLParameters(string[string] params)
{
	import std.array : appender;
	
	auto app = appender!string();

	bool first = true;
	foreach (key, val; params) {
		if (first) {
			app.put("?");
			first = false;
		}
		else {
			app.put("&");
		}
		app.put(key);
		app.put("=");
		app.put(val);
	}
	return app.data;
}

unittest
{
	assert(buildURLParameters(["foo" : "bar"]) == "?foo=bar");
	// Ordering isn't guaranteed
	assert(buildURLParameters(["foo" : "bar", "baz" : "biz"]) == "?foo=bar&baz=biz"
	       || buildURLParameters(["foo" : "bar", "baz" : "biz"]) == "?baz=biz&foo=bar");
}

class HTTPException : object.Exception {
	immutable HTTP.StatusLine statusLine;
	immutable string response;

	this(HTTP.StatusLine sl, string resp, string file = null, size_t line = 0)
	{
		statusLine = sl;
		response = resp;
		super(sl.toString(), file, line);
	}
}

void printHTTPException(const HTTPException ex)
{
	import std.stdio;

	stderr.writeln("Got HTTP ", ex.statusLine.code, " ", ex.statusLine.reason);
	switch (ex.statusLine.code) {
		case 404: stderr.writeln("(Is the issue ID correct?)"); break;
		case 401: stderr.writeln("(Are your credentials correct?)"); break;
		default: break;
	}
	stderr.writeln("Response was:");
	stderr.writeln(ex.response);
}

void enforce200(string file = __FILE__, size_t line = __LINE__)
	(ref HTTP request, string response)
{
	import std.exception;
	if (request.statusLine.code != 200) {
		throw new HTTPException(request.statusLine, response, file, line);
	}
}

// HTTP.postData only seems to work for POST and hangs otherwise,
// so we'll roll our own here.
// This is lovingly borrowed from how Phobos does the high-level HTTP stuff.
private @property outgoingString(ref HTTP request, const(void)[] sendData)
{
	import std.algorithm : min;

	request.contentLength = sendData.length;
	auto remainingData = sendData;
	request.onSend = delegate size_t(void[] buf)
	{
		size_t minLen = min(buf.length, remainingData.length);
		if (minLen == 0) return 0;
		buf[0..minLen] = remainingData[0..minLen];
		remainingData = remainingData[minLen..$];
		return minLen;
	};
}

/// POSTs the given content to the given URL with the given headers
JSONValue post(string url, string content, string[string] extraHeaders = null)
{
	import std.string : empty, strip;

	string response;

	auto request = HTTP(url);
	request.method = HTTP.Method.post;
	request.addRequestHeader("Content-Type", "application/json");
	foreach (key, val; extraHeaders) {
		request.addRequestHeader(key, val);
	}
	request.outgoingString = content;
	request.onReceive = (ubyte[] data) {
		response ~= cast(const(char)[])data;
		return data.length;
	};
	request.perform();
	enforce200(request, response);

	if (response.strip().empty) return JSONValue.init;
	else return toJSONValue(response);
}

/// Ditto, but with JSON
JSONValue post(string url, JSONValue content, string[string] extraHeaders = null)
{
	return post(url, content.toJSON!(GeneratorOptions.compact), extraHeaders);
}

/// GETs the given URL with the given headers
JSONValue get(string url, string[string] extraHeaders = null)
{
	string response;

	auto request = HTTP(url);
	request.method = HTTP.Method.get;
	request.addRequestHeader("Content-Type", "application/json");
	foreach (key, val; extraHeaders) {
		request.addRequestHeader(key, val);
	}
	request.onReceive = (ubyte[] data) {
		response ~= cast(const(char)[])data;
		return data.length;
	};
	request.perform();
	enforce200(request, response);
	return toJSONValue(response);
}
