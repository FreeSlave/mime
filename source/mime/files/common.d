/**
 * Common code for modules that read shared MIME-info database files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.common;

import mime.common;

///Exception thrown on parse errors while reading shared MIME-info database files.
final class MimeFileException : Exception
{
    this(string msg, string lineString, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
        _lineString = lineString;
    }

    ///The line that caused error. Don't confuse it with $(B line) property of $(B Throwable).
    @nogc @safe string lineString() const nothrow {
        return _lineString;
    }

private:
    string _lineString;
}

package enum string lineFilter = "!a.empty && a[0] != '#'";

package uint parseIndent(ref const(char)[] current)
{
    import std.exception : enforce;
    import std.conv : parse;
    enforce(current.length);
    uint indent = 0;

    if (current[0] != '>') {
        indent = parse!uint(current);
    }
    return indent;
}
