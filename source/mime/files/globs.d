module mime.files.globs;
import mime.common;

private {
    import std.algorithm;
    import std.conv;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

@nogc @safe bool isNoGlobs(string str) pure nothrow {
    return str == "__NOGLOBS__";
}

alias Tuple!(uint, "weight", string, "mimeType", string, "pattern", bool, "caseSensitive") GlobLine;

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
                throw new Exception("Malformed globs file: mime type and pattern must be presented");
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
