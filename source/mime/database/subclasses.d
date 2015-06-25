module mime.database.subclasses;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias Tuple!(string, "mimeType", string, "parent") SubclassLine; 

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
        throw new Exception("Malformed subclasses file: must be 3 words per line");
    });
}
