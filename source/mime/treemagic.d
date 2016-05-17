module treemagic;

import std.exception;
import mime.common;

struct TreeMatch
{
    enum Type {
        file,
        directory,
        link
    }
    
    @nogc @safe this(string itemPath, Type itemType) pure nothrow {
        path = itemPath;
        type = itemType;
    }
    
    string path;
    Type type;
    bool matchCase;
    bool executable;
    bool nonEmpty;
    string mimeType;
    
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
private:
    uint weight = defaultMatchWeight;
    TreeMatch[] matches;
}
