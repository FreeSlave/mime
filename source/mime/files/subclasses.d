/**
 * Parsing mime/subclasses files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.subclasses;

public import mime.files.common;

private {
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in subclasses file.
alias Tuple!(string, "mimeType", string, "parent") SubclassLine;

/**
 * Parse mime/subclasses file by line ignoring empty lines and comments.
 * Returns:
 *  Range of $(D SubclassLine) tuples.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto subclassesFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string)) {
    return byLine.filter!(lineFilter).map!(function(string line) {
        auto splitted = std.algorithm.splitter(line);
        if (!splitted.empty) {
            auto mimeType = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                auto parent = splitted.front;
                return SubclassLine(mimeType, parent);
            }
        }
        throw new MimeFileException("Malformed subclasses file: must be 2 words per line", line);
    });
}

///
unittest
{
    string[] lines = ["application/javascript application/ecmascript", "text/x-markdown text/plain"];
    auto expected = [SubclassLine("application/javascript", "application/ecmascript"), SubclassLine("text/x-markdown", "text/plain")];
    assert(equal(subclassesFileReader(lines), expected));

    assertThrown!MimeFileException(subclassesFileReader(["application/javascript"]).array, "must throw");
}
