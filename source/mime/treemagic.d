/**
 * Treemagic rules object representation.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.treemagic;

import std.exception;
import std.file;
import std.path;

import mime.common;
import mime.files.treemagic;

/**
 * One of treemagic rules in treemagic definition. Represents &lt;treematch&gt; element in source XML.
 */
struct TreeMatch
{
    ///Required type of file
    enum Type : ubyte {
        ///Any type
        any,
        ///Regular file
        file,
        ///Directory
        directory,
        ///Link
        link
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
    }

    ///
    @nogc @safe this(string path, Type type = Type.any, Options options = Options.none, string mimeType = null) pure nothrow {
        this.path = path;
        this.type = type;
        this.options = options;
        this.mimeType = mimeType;
    }

    ///Path to match.
    string path;

    ///Type of path.
    Type type;

    ///Path options.
    Options options;

    ///MIME type name.
    string mimeType;

    ///
    @nogc @safe bool executable() nothrow const pure
    {
        return (options & Options.executable) != 0;
    }

    ///
    @nogc @safe bool executable(bool exec) nothrow pure
    {
        if (exec)
            options |= Options.executable;
        else
            options &= ~cast(int)(Options.executable);
        return exec;
    }

    ///
    @nogc @safe bool matchCase() nothrow const pure
    {
        return (options & Options.matchCase) != 0;
    }

    ///
    @nogc @safe bool matchCase(bool mcase) nothrow pure
    {
        if (mcase)
            options |= Options.matchCase;
        else
            options &= ~cast(int)(Options.matchCase);
        return mcase;
    }

    ///
    @nogc @safe bool nonEmpty() nothrow const pure
    {
        return (options & Options.nonEmpty) != 0;
    }

    ///
    @nogc @safe bool nonEmpty(bool notEmpty) nothrow pure
    {
        if (notEmpty)
            options |= Options.nonEmpty;
        else
            options &= ~cast(int)(Options.nonEmpty);
        return notEmpty;
    }

    ///
    @nogc @safe auto submatches() nothrow const pure {
        return _submatches;
    }

    package @nogc @safe auto submatches() nothrow pure {
        return _submatches;
    }

    ///
    @safe void addSubmatch(TreeMatch match) nothrow pure {
        _submatches ~= match;
    }

    package @trusted TreeMatch clone() const nothrow pure {
        TreeMatch copy;
        copy.type = this.type;
        copy.path = this.path;
        copy.options = this.options;
        copy.mimeType = this.mimeType;

        foreach(match; _submatches) {
            copy.addSubmatch(match.clone());
        }
        return copy;
    }

    unittest
    {
        auto origin = TreeMatch("dir", Type.directory);
        origin.addSubmatch(TreeMatch("file", Type.file));
        origin.addSubmatch(TreeMatch("link", Type.link));

        const corigin = origin;
        assert(corigin.submatches().length == 2);

        auto shallow = origin;
        shallow.submatches()[0].type = Type.any;
        assert(origin.submatches()[0].type == Type.any);

        auto clone = origin.clone();
        clone.submatches()[1].path = "short";
        assert(origin.submatches()[1].path == "link");
    }

private:
    TreeMatch[] _submatches;
}

unittest
{
    auto match = TreeMatch("");

    match.executable = true;
    assert(match.executable);
    match.executable = false;
    assert(!match.executable);

    match.matchCase = true;
    assert(match.matchCase);
    match.matchCase = false;
    assert(!match.matchCase);

    match.nonEmpty = true;
    assert(match.nonEmpty);
    match.nonEmpty = false;
    assert(!match.nonEmpty);
}

/**
 * Treemagic definition. Represents &lt;treemagic&gt; element in souce XML.
 */
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

    package @nogc @safe auto matches() nothrow pure {
        return _matches;
    }

    /**
     * Add top-level match rule.
     */
    @safe void addMatch(TreeMatch match) nothrow pure {
        _matches ~= match;
    }

    package @trusted TreeMagic clone() const nothrow pure {
        auto copy = TreeMagic(this.weight());
        foreach(match; _matches) {
            copy.addMatch(match.clone());
        }
        return copy;
    }

    unittest
    {
        auto origin = TreeMagic(60);
        origin.addMatch(TreeMatch("path", TreeMatch.Type.directory));
        origin.addMatch(TreeMatch("path", TreeMatch.Type.directory));

        auto shallow = origin;
        shallow.matches()[0].type = TreeMatch.Type.file;
        assert(origin.matches()[0].type == TreeMatch.Type.file);

        const corigin = origin;
        assert(corigin.matches().length == 2);

        auto clone = origin.clone();
        clone.weight = 50;
        assert(origin.weight == 60);
        clone.matches()[1].type = TreeMatch.Type.link;
        assert(origin.matches()[1].type == TreeMatch.Type.directory);
    }

private:
    uint _weight = defaultMatchWeight;
    TreeMatch[] _matches;
}

private @trusted bool matchTreeMatch(string mountPoint, ref scope const TreeMatch match) nothrow
{
    import std.stdio;
    string path;
    uint attrs;

    if (match.options & TreeMatch.Options.matchCase) {
        path = buildPath(mountPoint, match.path);
        try {
            attrs = getLinkAttributes(path);
        } catch(Exception e) {
            return false;
        }
    } else {
        try {
            foreach(entry; dirEntries(mountPoint, SpanMode.shallow)) {
                if (filenameCmp!(CaseSensitive.no)(entry.name, buildPath(mountPoint, match.path)) == 0) {
                    path = entry.name;
                    attrs = entry.linkAttributes();
                    break;
                }
            }
        } catch(Exception e) {
            return false;
        }
    }

    bool ok;
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
                try {
                    ok = access(toStringz(path), X_OK) == 0;
                } catch(Exception e) {
                    ok = false;
                }

            } else version(Windows) {
                ok = filenameCmp(path.extension, ".exe") == 0;
            }
        }
        if (ok && (match.options & TreeMatch.Options.nonEmpty)) {
            try {
                ok = !dirEntries(path, SpanMode.shallow).empty;
            } catch(Exception e) {
                return false;
            }
        }
        if (ok && match.mimeType.length) {
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
@safe bool matchTreeMagic(string mountPoint, ref scope const TreeMagic treeMagic) nothrow
{
    foreach(match; treeMagic.matches) {
        if (matchTreeMatch(mountPoint, match)) {
            return true;
        }
    }
    return false;
}

/**
 * Detect MIME type of mounted device using treemagic file.
 * Params:
 *  mountPoint = Path to mount point of device.
 *  treemagicPath = Path to treemagic file.
 * Returns: MIME type name or null if could not detect.
 * See_Also: $(D mime.files.treeMagicFileReader)
 */
@trusted string treeMimeType(string mountPoint, scope string treemagicPath)
{
    auto data = assumeUnique(read(treemagicPath));

    string mimeType;
    void sink(TreeMagicEntry t) {
        if (mimeType.length == 0 && matchTreeMagic(mountPoint, t.magic)) {
            mimeType = t.mimeType;
        }
    }
    treeMagicFileReader(data, &sink);
    return mimeType;
}

/**
 * Detect MIME type of mounted device using treemagic files.
 * Params:
 *  mountPoint = Path to mount point of device.
 *  mimePaths = Base mime directories where treemagic files are usually placed.
 * Returns: MIME type name or null if could not detect.
 * See_Also: $(D mime.paths.mimePaths)
 */
@safe string treeMimeType(string mountPoint, scope const(string)[] mimePaths) nothrow
{
    foreach(mimePath; mimePaths) {
        try {
            string treemagicPath = buildPath(mimePath, "treemagic");
            string mimeType = treeMimeType(mountPoint, treemagicPath);
            if (mimeType.length) {
                return mimeType;
            }
        } catch(Exception e) {

        }
    }
    return null;
}

///
unittest
{
    auto mimePaths = ["test/mime"];
    assert(treeMimeType("test/media/photos", mimePaths) == "x-content/image-dcf");
    assert(treeMimeType("test/media/installer", mimePaths) == "x-content/unix-software");
    assert(treeMimeType("test", mimePaths) == null);
}
