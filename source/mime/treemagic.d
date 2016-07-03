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
        ///File must have executable permissions.
        executable = 1,
        ///Path match is case-sensitive.
        matchCase = 2,
        ///Directory must non-empty.
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

private @trusted bool matchTreeMatch(string mountPoint, ref const TreeMatch match) nothrow
{
    import std.file;
    import std.path;
    
    string path = buildPath(mountPoint, match.path);
    bool ok;
    
    uint attrs;
    try {
        attrs = getLinkAttributes(path);
    } catch(Exception e) {
        return false;
    }
    
    final switch(match.type) {
        case TreeMatch.Type.file:
            ok = attrIsFile(attrs);
            break;
        case TreeMatch.Type.directory:
            ok = attrIsDir(attrs);
            break;
        case TreeMatch.Type.link:
            ok = attrIsSymlink(attrs);
            break;
        case TreeMatch.Type.any:
            ok = true;
            break;
    }
    
    if (ok) {
        if (ok && (match.options & TreeMatch.Options.executable) && attrIsFile(attrs)) {
            version(Posix) {
                import core.sys.posix.unistd;
                import std.string : toStringz;
                ok = access(toStringz(path), X_OK) == 0;
            } else version(Windows) {
                ok = filenameCmp(path.extension, ".exe") == 0;
            }
        }
        if (ok && (match.options & TreeMatch.Options.matchCase)) {
            //TODO: implement
        }
        if (ok && (match.options & TreeMatch.Options.nonEmpty)) {
            try {
                ok = dirEntries(path, SpanMode.shallow).empty;
            } catch(Exception e) {
                return false;
            }
        }
        if (ok && (match.options & TreeMatch.Options.mimeType)) {
            //TODO: implement
        }
        
        if (ok && match.submatches().length) {
            foreach(submatch; match.submatches()) {
                if (matchTreeMatch(mountPoint, submatch)) {
                    return true;
                }
            }
            return false;
        }
    }
    
    return ok;
}

/**
 * Test if layout of mountPoint matches given treeMagic.
 * Note: This function does not check if mountPoint is actually mount point.
 * See_Also: $(D mime.inode.inodeMimeType)
 */
@safe bool matchTreeMagic(string mountPoint, ref const TreeMagic treeMagic) nothrow
{
    foreach(match; treeMagic.matches) {
        if (matchTreeMatch(mountPoint, match)) {
            return true;
        }
    }
    return false;
}
