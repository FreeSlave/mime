/**
 * Struct that represents a MIME glob pattern.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2018
 */

module mime.glob;

import mime.common;

/**
 * Glob pattern for detecting MIME type of file by its name.
 */
struct MimeGlob
{
    ///
    @nogc @safe this(string glob, uint priority = defaultGlobWeight, bool cs = false) nothrow pure {
        pattern = glob;
        weight = priority;
        caseSensitive = cs;
    }

    ///
    unittest
    {
        auto mimeGlob = MimeGlob("*.txt", 60, true);
        assert(mimeGlob.pattern == "*.txt");
        assert(mimeGlob.weight == 60);
        assert(mimeGlob.caseSensitive);

        mimeGlob = MimeGlob.init;
        assert(mimeGlob.pattern == "");
        assert(mimeGlob.weight == defaultGlobWeight);
    }

    ///Glob pattern as string.
    string pattern;
    ///Priority of pattern.
    uint weight = defaultGlobWeight;
    ///Tells whether the pattern should be considered case sensitive or not.
    bool caseSensitive;

    ///Member version of static isLiteral. Uses pattern as argument.
    @nogc @safe bool isLiteral() nothrow pure const {
        return isLiteral(pattern);
    }
    ///
    unittest
    {
        auto mimeGlob = MimeGlob("Makefile");
        assert(mimeGlob.isLiteral());
    }

    ///Member version of static isSuffix. Uses pattern as argument.
    @nogc @safe bool isSuffix() nothrow pure const {
        return isSuffix(pattern);
    }
    ///
    unittest
    {
        auto mimeGlob = MimeGlob("*.txt");
        assert(mimeGlob.isSuffix());
    }

    ///Member version of static isGenericGlob. Uses pattern as argument.
    @nogc @safe bool isGenericGlob() nothrow pure const {
        return isGenericGlob(pattern);
    }
    ///
    unittest
    {
        auto mimeGlob = MimeGlob("lib*.so.[0-9]");
        assert(mimeGlob.isGenericGlob());
    }

    private @nogc @safe static bool isGlobSymbol(char c) nothrow pure {
        return c == '*' || c == '[' || c == '?';
    }

    /**
     * Check if glob pattern is literal, i.e. does not have special glob match characters.
     */
    @nogc @safe static bool isLiteral(scope string pattern) nothrow pure {
        if (pattern.length == 0) {
            return false;
        }
        for (size_t i=0; i<pattern.length; ++i) {
            if (isGlobSymbol(pattern[i])) {
                return false;
            }
        }
        return true;
    }

    ///
    unittest
    {
        assert(isLiteral("Makefile"));
        assert(!isLiteral(""));
        assert(!isLiteral("pak[0-9].pak"));
    }

    /**
     * Check if glob pattern is suffix, i.e. starts with '*' and does not have special glob match characters in the rest of pattern.
     */
    @nogc @safe static bool isSuffix(scope string pattern) nothrow pure {
        if (pattern.length > 1 && pattern[0] == '*') {
            for (size_t i=1; i<pattern.length; ++i) {
                if (isGlobSymbol(pattern[i])) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    ///
    unittest
    {
        assert(isSuffix("*.jpg"));
        assert(!isSuffix(""));
        assert(!isSuffix("*"));
        assert(!isSuffix("*dir[0-9]"));
    }

    /**
     * Check if glob pattern is something else besides literal and suffix.
     */
    @nogc @safe static bool isGenericGlob(scope string pattern) nothrow pure {
        return pattern.length > 0 && !isLiteral(pattern) && !isSuffix(pattern);
    }

    ///
    unittest
    {
        assert(isGenericGlob("lib*.so"));
        assert(isGenericGlob("*dir[0-9]"));
        assert(!isGenericGlob(""));
        assert(!isGenericGlob("Makefile"));
        assert(!isGenericGlob("*.bmp"));
    }
}

deprecated("Use MimeGlob") alias MimeGlob MimePattern;
