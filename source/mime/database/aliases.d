module mime.database.aliases;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias Tuple!(string, "aliasName", string, "mimeType") AliasLine;

@trusted auto aliasesFileReader(Range)(Range byLine) if(is(ElementType!Range : string)) {
    return byLine.map!(function(string line) {
        auto splitted = line.splitter;
        if (!splitted.empty) {
            auto aliasName = splitted.front;
            splitted.popFront();
            if (!splitted.empty) {
                auto mimeType = splitted.front;
                return AliasLine(mimeType, parent);
            }
        }
        throw Exception("Malformed aliases file: must be 2 words per line");
    });
}

