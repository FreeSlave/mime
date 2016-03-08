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

package {
    version(OSX) {
        enum isFreedesktop = false;
    } else version(Android) {
        enum isFreedesktop = false;
    } else version(Posix) {
        enum isFreedesktop = true;
    } else {
        enum isFreedesktop = false;
    }
}

/**
 * Get shared MIME database paths based on dataPaths.
 * Returns:
 *  Range of paths where MIME database files are stored.
 * 
 */
@trusted auto mimePaths(Range)(Range dataPaths) if(isInputRange!Range && is(ElementType!Range : string)) {
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
    @trusted auto mimePaths() {
        string[] result;
        collectException(std.algorithm.splitter(environment.get("XDG_DATA_DIRS"), ':').map!(p => buildPath(p, "mime")).array, result);
        if (result.empty) {
            result = ["/usr/local/share/mime", "/usr/share/mime"];
        }
        string homeMimeDir = writableMimePath();
        if(homeMimeDir.length) {
            result = homeMimeDir ~ result;
        }
        return result;
    }
    
    ///
    unittest
    {
        try {
            environment["XDG_DATA_DIRS"] = "/myuser/share:/myuser/share/local";
            environment["XDG_DATA_HOME"] = "/home/myuser/share";
            
            assert(equal(mimePaths(), ["/home/myuser/share/mime", "/myuser/share/mime", "/myuser/share/local/mime"]));
            
            environment["XDG_DATA_DIRS"] = "";
            assert(equal(mimePaths(), ["/home/myuser/share/mime", "/usr/local/share/mime", "/usr/share/mime"]));
        }
        catch (Exception e) {
            import std.stdio;
            stderr.writeln("environment error in unittest", e.msg);
        }
    }
    
    /**
     * Get writable path where shared MIME database is stored.
     * Returns:
     *  Writable MIME path for the current user ($HOME/.local/share/mime).
     * Note: this function does not check if the path exist and appears to be directory.
     * This function is available only of freedesktop systems.
     */
    @safe string writableMimePath() nothrow {
        string dir;
        collectException(environment.get("XDG_DATA_HOME"), dir);
        if (!dir.length) {
            string home;
            collectException(environment.get("HOME"), home);
            if (home.length) {
                return buildPath(home, ".local/share/mime");
            }
        } else {
            return buildPath(dir, "mime");
        }
        return null;
    }
    
    ///
    unittest
    {
        try {
            environment["XDG_DATA_HOME"] = "/home/myuser/share";
            assert(writableMimePath() == "/home/myuser/share/mime");
            
            environment["XDG_DATA_HOME"] = "";
            assert(writableMimePath() == buildPath(environment["HOME"], ".local/share/mime"));
        }
        catch(Exception e) {
            import std.stdio;
            stderr.writeln("environment error in unittest", e.msg);
        }
    }
}
