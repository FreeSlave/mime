/**
 * Parsing mime/subclasses files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.files.subclasses;

public import mime.files.exception;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

///Represents one line in subclasses file.
alias Tuple!(string, "mimeType", string, "parent") SubclassLine; 

/**
 * Parse mime/subclasses file by line ignoring empty lines and comments.
 * Returns:
 *  Range of SubclassLine tuples.
 * Throws:
 *  MimeFileException on parsing error.
 */
@trusted auto subclassesFileReader(Range)(Range byLine) if(is(ElementType!Range : string)) {
    return byLine.map!(function(string line) {
        auto splitted = line.splitter;
        if (!splitted.empty) {
            auto mimeType = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                auto parent = splitted.front;
                return SubclassLine(mimeType, parent);
            }
        }
        throw new MimeFileException("Malformed subclasses file: must be 3 words per line", line);
    });
}
