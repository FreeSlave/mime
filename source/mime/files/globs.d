/**
 * Parsing mime/globs and mime/globs2 files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.globs;

public import mime.files.common;

private {
    import mime.common : defaultGlobWeight, isNoGlobs;

    import std.algorithm;
    import std.conv : parse;
    import std.exception;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in globs or globs2 file.
alias Tuple!(uint, "weight", string, "mimeType", string, "pattern", bool, "caseSensitive") GlobLine;

/**
 * Parse mime/globs file by line ignoring empty lines and comments.
 * Returns:
 *  Range of $(D GlobLine) tuples.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto globsFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string))
{
    return byLine.filter!(lineFilter).map!(function(string line) {
        auto splitted = line.splitter(':');
        string mimeType, pattern;

        if (!splitted.empty) {
            mimeType = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                pattern = splitted.front;
                splitted.popFront();
            } else {
                throw new MimeFileException("Malformed globs file: mime type and pattern must be presented", line);
            }
        }

        if (!mimeType.length || !pattern.length) {
            throw new MimeFileException("Malformed globs file: the line has wrong format", line);
        }

        return GlobLine(isNoGlobs(pattern) ? 0 : defaultGlobWeight, mimeType, pattern, false);
    });
}

///
unittest
{
    string[] lines = ["#comment", "text/x-c++src:*.cpp", "text/x-csrc:*.c"];
    auto expected = [GlobLine(defaultGlobWeight, "text/x-c++src", "*.cpp", false), GlobLine(defaultGlobWeight, "text/x-csrc", "*.c", false)];
    assert(equal(globsFileReader(lines), expected));
    assert(equal(globsFileReader(["text/plain:__NOGLOBS__"]), [GlobLine(0, "text/plain", "__NOGLOBS__", false)]));

    assertThrown!MimeFileException(globsFileReader(["#comment", "text/plain:*.txt", "nocolon"]).array, "must throw");
}

/**
 * Parse mime/globs2 file by line ignoring empty lines and comments.
 * Returns:
 *  Range of $(D GlobLine) tuples.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto globs2FileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string))
{
    return byLine.filter!(lineFilter).map!(function(string line) {
        auto splitted = line.splitter(':');
        string weightStr, mimeType, pattern, optionsStr;

        if (!splitted.empty) {
            weightStr = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                mimeType = splitted.front;
                splitted.popFront();
                if (!splitted.empty) {
                    pattern = splitted.front;
                    splitted.popFront();
                    if (!splitted.empty) {
                        optionsStr = splitted.front;
                        splitted.popFront();
                    }
                }
            }
        }

        if (!weightStr.length || !mimeType.length || !pattern.length) {
            throw new MimeFileException("Malformed globs2 file: the line has wrong format", line);
        }

        uint weight;
        try {
            weight = parse!uint(weightStr);
        } catch(Exception e) {
            throw new MimeFileException(e.msg, line, e.file, e.line, e.next);
        }

        auto flags = optionsStr.splitter(','); //The fourth field contains a list of comma-separated flags
        bool cs = !flags.empty && flags.front == "cs";
        return GlobLine(weight, mimeType, pattern, cs);
    });
}

///
unittest
{
    string[] lines = [
        "#comment",
        "50:text/x-c++src:*.cpp",
        "60:text/x-c++src:*.C:cs",
        "50:text/x-csrc:*.c:cs"
    ];

    auto expected = [GlobLine(50, "text/x-c++src", "*.cpp", false), GlobLine(60, "text/x-c++src", "*.C", true), GlobLine(50, "text/x-csrc", "*.c", true)];
    assert(equal(globs2FileReader(lines), expected));

    assertThrown!MimeFileException(globs2FileReader(["notanumber:text/plain:*.txt"]).array, "must throw");

    MimeFileException mfe;
    try {
        globs2FileReader(["notanumber:text/nopattern"]).array;
    } catch(MimeFileException e) {
        mfe = e;
        assert(mfe.lineString == "notanumber:text/nopattern");
    }
    assert(mfe, "must throw");
}
