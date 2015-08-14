module mime.paths;

private {
    import std.algorithm;
    import std.path;
    import std.range;
    import std.traits;
}

@trusted auto mimePaths(Range)(Range dataPaths) if(is(ElementType!Range : string)) {
    return dataPaths.map!(p => buildPath(p, "mime"));
}


version(OSX) {}
else version(Posix) {
    import standardpaths;
    @trusted auto mimePaths() {
        return mimePaths(standardPaths(StandardPath.Data));
    }
    
    @safe string writableMimePath() nothrow {
        string dataPath = writablePath(StandardPath.Data);
        if (dataPath.length) {
            return buildPath(dataPath, "mime");
        }
        return null;
    }
}
