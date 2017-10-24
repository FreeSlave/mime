/**
 * Parsing mime/types files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.files.types;

import mime.common;
public import mime.files.common;

private {
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.string;
    import std.traits;
}


/**
 * Parse mime/types file by line ignoring empty lines and comments.
 * Returns:
 *  Range of mime type names.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto typesFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string)) {
    return byLine.filter!(lineFilter).map!(function(string line) {
        line = line.stripRight;
        if (isValidMimeTypeName(line)) {
            return line;
        } else {
            throw new MimeFileException("Malformed types file: invalid MIME type name", line);
        }
    });
}

///
unittest
{
    string[] lines = ["#comment", "", "application/x-md2", "application/x-md3"];
    assert(equal(lines[2..$], typesFileReader(lines)));

    assertThrown(typesFileReader(["notmimetype"]).array, "must throw");
}
