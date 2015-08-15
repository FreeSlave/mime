/**
 * Functions for building and retrieving paths to shared MIME database directories.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.paths;

private {
    import std.algorithm;
    import std.path;
    import std.range;
    import std.traits;
}

/**
 * Get shared MIME database paths based on dataPaths.
 * Returns:
 *  Range of paths where MIME database files are stored.
 * 
 */
@trusted auto mimePaths(Range)(Range dataPaths) if(is(ElementType!Range : string)) {
    return dataPaths.map!(p => buildPath(p, "mime"));
}


version(OSX) {}
else version(Posix) {
    import standardpaths;
    /**
     * Get shared MIME database paths in system.
     * This function is available only of freedesktop systems.
     * Note: This function does not check if paths exist and appear to be directories.
     * Returns:
     *  Range of MIME paths in the order of preference from the most preferable to the least. 
     * Usually it's the same as $HOME/.local/share/mime, /usr/local/share/mime and /usr/share/mime.
     */
    @trusted auto mimePaths() {
        return mimePaths(standardPaths(StandardPath.Data));
    }
    
    /**
     * Get writable path where shared MIME database is stored.
     * Returns:
     *  Writable MIME path for the current user ($HOME/.local/share/mime).
     * Note: this function does not check if the path exist and appears to be directory.
     * This function is available only of freedesktop systems.
     */
    @safe string writableMimePath() nothrow {
        string dataPath = writablePath(StandardPath.Data);
        if (dataPath.length) {
            return buildPath(dataPath, "mime");
        }
        return null;
    }
}
