/**
 * Parsing mime/XMLnamespaces files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.files.namespaces;

public import mime.files.exception;

private {
    import std.algorithm;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in XMLnamespaces file.
alias Tuple!(string, "namespaceUri", string, "localName", string, "mimeType") NamespaceLine;

/**
 * Parse mime/XMLnamespaces file by line ignoring empty lines and comments.
 * Returns:
 *  Range of NamespaceLine tuples.
 * Throws:
 *  MimeFileException on parsing error.
 */
@trusted auto namespacesFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string)) {
    return byLine.filter!(s => !s.empty).map!(function(string line) {
        auto splitted = std.algorithm.splitter(line);
        if (!splitted.empty) {
            auto namespaceUri = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                auto localName = splitted.front;
                splitted.popFront();
                if (!splitted.empty) {
                    auto mimeType = splitted.front;
                    return NamespaceLine(namespaceUri, localName, mimeType);
                }
            }
        }
        throw new MimeFileException("Malformed namespaces file: must be 3 words per line", line);
    });
}

///
unittest
{
    string[] lines = ["http://www.w3.org/1999/xhtml html application/xhtml+xml", "http://www.w3.org/2000/svg svg image/svg+xml"];
    auto expected = [NamespaceLine("http://www.w3.org/1999/xhtml", "html", "application/xhtml+xml"), NamespaceLine("http://www.w3.org/2000/svg", "svg", "image/svg+xml")];
    assert(equal(namespacesFileReader(lines), expected));
}
