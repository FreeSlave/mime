/**
 * Parsing mime/aliases files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.files.aliases;

public import mime.files.exception;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

///Represents one line in aliases file.
alias Tuple!(string, "aliasName", string, "mimeType") AliasLine;

/**
 * Parse mime/aliases file by line ignoring empty lines and comments.
 * Returns:
 *  Range of AliasLine tuples.
 * Throws:
 *  MimeFileException on parsing error.
 */
@trusted auto aliasesFileReader(Range)(Range byLine) if(is(ElementType!Range : string)) {
    return byLine.filter!(s => !s.empty).map!(function(string line) {
        auto splitted = line.splitter;
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

