module mime.common;

private {
    import std.algorithm;
    import std.path;
    import std.range;
    import std.traits;
    import standardpaths;
}

@trusted auto mimePaths(Range)(Range dataPaths) if(is(ElementType!Range : string)) {
    return dataPaths.map!(p => buildPath(p, "mime")).retro;
}

@trusted auto mimePaths() {
    return mimePaths(standardPaths(StandardPath.Data));
}

package
{
    template mimePathsBuilder(string name)
    {
        @trusted auto mimePathsBuilder(Range)(Range mimePaths) {
            return mimePaths.map!(p => buildPath(p, name));
        }
    }
}

