module mime.treemagic;

import std.exception;
import mime.common;

struct TreeMatch
{
    ///Required type of file
    enum Type : ubyte {
        ///Regular file
        file = 1,
        ///Directory
        directory,
        ///Link
        link,
        ///Any type
        any
    }
    
    enum Options : ubyte {
        ///No specific options.
        none = 0,
        ///Path must have executable permissions.
        executable = 1,
        ///Path match is case-sensitive.
        matchCase = 2,
        ///File or directory must non-empty.
        nonEmpty = 4,
        ///File must be of type mimeType.
        mimeType = 8
    }
    
    @nogc @safe this(string itemPath, Type itemType, Options itemOptions = Options.none) pure nothrow {
        path = itemPath;
        type = itemType;
        options = itemOptions;
    }
    
    string path;
    Type type;
    Options options;
    string mimeType;
    
    @nogc @safe auto submatches() nothrow const pure {
        return _submatches;
    }
    
    @safe void addSubmatch(TreeMatch match) nothrow pure {
        _submatches ~= match;
    }
    
private:
    TreeMatch[] _submatches;
}

struct TreeMagic
{
    /**
     * Constructor.
     * Params:
     *  weight = Priority of this magic rule.
     */
    @nogc @safe this(uint weight) nothrow pure {
        _weight = weight;
    }
    /**
     * Priority for magic rule.
     */
    @nogc @safe uint weight() const nothrow pure {
        return _weight;
    }
    
    /**
     * Set priority for this rule.
     */
    @nogc @safe uint weight(uint priority) nothrow pure {
        return _weight = priority;
    }
    
    /**
     * Get path match rules
     * Returns: Array of $(D TreeMatch) elements.
     */
    @nogc @safe auto matches() const nothrow pure {
        return _matches;
    }
    
    /**
     * Add top-level match rule.
     */
    @safe void addMatch(TreeMatch match) nothrow pure {
        _matches ~= match;
    }
private:
    uint _weight = defaultMatchWeight;
    TreeMatch[] _matches;
}
