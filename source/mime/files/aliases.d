/**
 * Parsing mime/aliases files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.aliases;

public import mime.files.common;

private {
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in aliases file.
alias Tuple!(string, "aliasName", string, "mimeType") AliasLine;

/**
 * Parse mime/aliases file by line ignoring empty lines and comments.
 * Returns:
 *  Range of $(D AliasLine) tuples.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto aliasesFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string)) {
    return byLine.filter!(lineFilter).map!(function(string line) {
        auto splitted = std.algorithm.splitter(line);
        if (!splitted.empty) {
            auto aliasName = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                auto mimeType = splitted.front;
                return AliasLine(aliasName, mimeType);
            }
        }
        throw new MimeFileException("Malformed aliases file: must be 2 words per line", line);
    });
}

///
unittest
{
    string[] lines = ["application/acrobat application/pdf", "application/ico image/vnd.microsoft.icon"];
    auto expected = [AliasLine("application/acrobat", "application/pdf"), AliasLine("application/ico", "image/vnd.microsoft.icon")];
    assert(equal(aliasesFileReader(lines), expected));

    assertThrown!MimeFileException(aliasesFileReader(["application/aliasonly"]).array, "must throw");
}
