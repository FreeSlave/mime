module mime.database.icons;

private {
    import std.algorithm;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias Tuple!(string, "mimeType", string, "iconName") IconLine;

@trusted auto iconsFileReader(Range)(Range byLine) if(is(ElementType!Range : string))
{
    return byLine.filter!(s => !s.empty).map!(function(string line) {
        auto result = findSplit(line, ":");
        if (result[1].empty) {
            throw new Exception("Malformed icons file");
        } else {
            return IconLine(result[0], result[2]);
        }
    });
}
