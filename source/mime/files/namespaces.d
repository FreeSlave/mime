/**
 * Parsing mime/XMLnamespaces files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.namespaces;

public import mime.files.common;

private {
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in XMLnamespaces file.
alias Tuple!(string, "namespaceUri", string, "localName", string, "mimeType") NamespaceLine;

/**
 * Parse mime/XMLnamespaces file by line ignoring empty lines and comments.
 * Returns:
 *  Range of $(D NamespaceLine) tuples.
 * Throws:
 *  $(D mime.files.common.MimeFileException) on parsing error.
 */
auto namespacesFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string)) {
    return byLine.filter!(lineFilter).map!(function(string line) {
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

    assertThrown!MimeFileException(namespacesFileReader(["http://www.example.org nameonly"]).array, "must throw");
    assertThrown!MimeFileException(namespacesFileReader(["http://www.example.org"]).array, "must throw");
}
