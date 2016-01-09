/**
 * Parsing mime/icons and mime/generic-icons files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.files.icons;

public import mime.files.exception;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

///Represents one line in icons file.
alias Tuple!(string, "mimeType", string, "iconName") IconLine;

/**
 * Parse mime/icons or mime/generic-icons file by line ignoring empty lines and comments.
 * Returns:
 *  Range of IconLine tuples.
 * Throws:
 *  MimeFileException on parsing error.
 */
@trusted auto iconsFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string))
{
    return byLine.filter!(s => !s.empty).map!(function(string line) {
        auto result = findSplit(line, ":");
        if (result[1].empty) {
            throw new MimeFileException("Malformed icons file", line);
        } else {
            return IconLine(result[0], result[2]);
        }
    });
}

///
unittest
{
    string[] lines = ["application/x-archive:package-x-generic", "application/x-perl:text-x-script"];
    auto expected = [IconLine("application/x-archive", "package-x-generic"), IconLine("application/x-perl", "text-x-script")];
    assert(equal(iconsFileReader(lines), expected));
}
