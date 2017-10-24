/**
 * Functions for building and retrieving paths to shared MIME database directories.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
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
    version(unittest) {
        import std.process : environment;

        package struct EnvGuard
        {
            this(string env) {
                envVar = env;
                envValue = environment.get(env);
            }

            ~this() {
                if (envValue is null) {
                    environment.remove(envVar);
                } else {
                    environment[envVar] = envValue;
                }
            }

            string envVar;
            string envValue;
        }
    }

    /**
     * Get shared MIME database paths in system.
     *
     * $(BLUE This function is Freedesktop only).
     * Note: This function does not check if paths exist and appear to be directories.
     * Returns:
     *  Range of MIME paths in the order of preference from the most preferable to the least.
     * Usually it's the same as $HOME/.local/share/mime, /usr/local/share/mime and /usr/share/mime.
     */
    @safe auto mimePaths() {
        return xdgAllDataDirs("mime");
    }

    ///
    unittest
    {
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME");
        auto dataDirsGuard = EnvGuard("XDG_DATA_DIRS");

        environment["XDG_DATA_HOME"] = "/home/user/data";
        environment["XDG_DATA_DIRS"] = "/usr/local/data:/usr/data";

        assert(mimePaths() == [
            "/home/user/data/mime", "/usr/local/data/mime", "/usr/data/mime"
        ]);
    }

    /**
     * Get writable path where shared MIME database is stored.
     *
     * $(BLUE This function is Freedesktop only).
     * Returns:
     *  Writable MIME path for the current user ($HOME/.local/share/mime).
     * Note: this function does not check if the path exist and appears to be directory.
     */
    @safe string writableMimePath() nothrow {
        return xdgDataHome("mime");
    }

    ///
    unittest
    {
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME");

        environment["XDG_DATA_HOME"] = "/home/user/data";

        assert(writableMimePath() == "/home/user/data/mime");
    }
}
