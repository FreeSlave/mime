/**
 * Parsing mime/globs and mime/globs2 files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.files.globs;

public import mime.files.exception;

private {
    import mime.common : defaultGlobWeight;
    
    import std.algorithm;
    import std.conv : parse;
    import std.range;
    import std.traits;
    import std.typecons;
}

///Represents one line in globs or globs2 file.
alias Tuple!(uint, "weight", string, "mimeType", string, "pattern", bool, "caseSensitive") GlobLine;

/**
 * Parse mime/globs or mime/globs2 file by line ignoring empty lines and comments.
 * Returns:
 *  Range of GlobLine tuples.
 * Throws:
 *  MimeFileException on parsing error.
 */
@trusted auto globsFileReader(Range)(Range byLine) if(isInputRange!Range && is(ElementType!Range : string))
{
    return byLine.filter!(s => !s.empty && !s.startsWith("#")).map!(function(string line) {
        auto splitted = line.splitter(':');
        string first, second, third, fourth;
        
        if (!splitted.empty) {
            first = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                second = splitted.front;
                splitted.popFront();
                if (!splitted.empty) {
                    third = splitted.front;
                    splitted.popFront();
                    if (!splitted.empty) {
                        fourth = splitted.front;
                        splitted.popFront();
                    }
                }
            } else {
                throw new MimeFileException("Malformed globs file: mime type and pattern must be presented", line);
            }
        }
        
        if (!third.empty) { //globs version 2
            uint weight = parse!uint(first);
            auto type = second;
            auto pattern = third;
            
            auto flags = fourth.splitter(','); //The fourth field contains a list of comma-separated flags
            bool cs = !flags.empty && flags.front == "cs";
            return GlobLine(weight, type, pattern, cs);
        } else { //globs version 1
            auto type = first;
            auto pattern = second;
            return GlobLine(defaultGlobWeight, type, pattern, false);
        }
    });
}

///
unittest
{
    string[] lines = [
        "50:text/x-c++src:*.cpp",
        "60:text/x-c++src:*.C:cs",
        "50:text/x-csrc:*.c:cs"
    ];
    
    auto expected = [GlobLine(50, "text/x-c++src", "*.cpp", false), GlobLine(60, "text/x-c++src", "*.C", true), GlobLine(50, "text/x-csrc", "*.c", true)];
    assert(equal(globsFileReader(lines), expected));
    
    lines = ["text/x-c++src:*.cpp", "text/x-csrc:*.c"];
    expected = [GlobLine(defaultGlobWeight, "text/x-c++src", "*.cpp", false), GlobLine(defaultGlobWeight, "text/x-csrc", "*.c", false)];
    assert(equal(globsFileReader(lines), expected));
}
