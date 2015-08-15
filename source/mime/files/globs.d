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
import mime.common;

private {
    import std.algorithm;
    import std.conv;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

/**
 * Check is pattern is __NOGLOBS__. This means glob patterns from less preferable MIME paths should be ignored.
 */
@nogc @safe bool isNoGlobs(string pattern) pure nothrow {
    return pattern == "__NOGLOBS__";
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
@trusted auto globsFileReader(Range)(Range byLine) if(is(ElementType!Range : string))
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
            auto type = second;
            auto pattern = third;
            uint weight = pattern.isNoGlobs ? 0 : parse!uint(first);
            
            auto flags = fourth.splitter(','); //The fourth field contains a list of comma-separated flags
            bool cs = !flags.empty && flags.front == "cs";
            return GlobLine(weight, type, pattern, cs);
        } else { //globs version 1
            auto type = first;
            auto pattern = third;
            return GlobLine(0, type, pattern, false);
        }
    });
}
