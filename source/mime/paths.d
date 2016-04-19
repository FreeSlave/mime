/**
 * Functions for building and retrieving paths to shared MIME database directories.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.paths;

private {
    import std.algorithm;
    import std.path;
    import std.range;
    import std.traits;
}

package {
    import isfreedesktop;
    import xdgpaths;
}

/**
 * Get shared MIME database paths based on dataPaths.
 * Returns:
 *  Range of paths where MIME database files are stored.
 * 
 */
auto mimePaths(Range)(Range dataPaths) if(isInputRange!Range && is(ElementType!Range : string)) {
    return dataPaths.map!(p => buildPath(p, "mime"));
}

///
unittest
{
    auto dataPaths = ["share", buildPath("local", "share")];
    assert(equal(mimePaths(dataPaths), [buildPath("share", "mime"), buildPath("local", "share", "mime")]));
}


static if (isFreedesktop) {
    import std.process : environment;
    import std.exception : collectException;
    
    /**
     * Get shared MIME database paths in system.
     * This function is available only of freedesktop systems.
     * Note: This function does not check if paths exist and appear to be directories.
     * Returns:
     *  Range of MIME paths in the order of preference from the most preferable to the least. 
     * Usually it's the same as $HOME/.local/share/mime, /usr/local/share/mime and /usr/share/mime.
     */
    @safe auto mimePaths() {
        return xdgAllDataDirs("mime");
    }
    
    /**
     * Get writable path where shared MIME database is stored.
     * Returns:
     *  Writable MIME path for the current user ($HOME/.local/share/mime).
     * Note: this function does not check if the path exist and appears to be directory.
     * This function is available only of freedesktop systems.
     */
    @safe string writableMimePath() nothrow {
        return xdgDataHome("mime");
    }
}
