module mime.database.icons;

import mime.common;

private {
    import std.algorithm;
    import std.path;
    import std.range;
    import std.stdio;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias mimePathsBuilder!"icons" mimeIconsPaths;

@trusted auto mimeGenericIconsPaths(Range)(Range mimePaths) if(is(ElementType!Range : string)) {
    return mimePaths.map!(p => buildPath(p, "generic-icons"));
}

@trusted auto mimeGenericIconsPaths() {
    return mimeIconsPaths(mimePaths());
}

alias Tuple!(string, "typeName", string, "iconName") IconLine;

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

@trusted auto iconsFileReader(string fileName) {
    return iconsFileReader(File(fileName, "r").byLine().map!(s => s.idup));
}
