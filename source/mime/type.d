/**
 * Struct that represents a MIME type.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.type;

import mime.common;
public import mime.magic;
public import mime.glob;
public import mime.treemagic;

private {
    import std.algorithm;
    import std.range;
}

/**
 * Represents single MIME type.
 */
final class MimeType
{
    /**
     * Create MIME type with name.
     * Name should be given in the form of media/subtype.
     */
    @nogc @safe this(string name) nothrow pure {
        _name = name;
    }

    ///The name of MIME type.
    @nogc @safe string name() nothrow const pure {
        return _name;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/plain");
        assert(mimeType.name == "text/plain");
        mimeType.name = "text/xml";
        assert(mimeType.name == "text/xml");
    }

    ///Set MIME type name.
    @nogc @safe string name(string typeName) nothrow pure {
        _name = typeName;
        return _name;
    }

    ///Array of MIME glob patterns applied to this MIME type.
    @nogc @safe const(MimeGlob)[] globs() nothrow const pure {
        return _globs;
    }

    deprecated("Use globs") alias globs patterns;

    ///Aliases to this MIME type.
    @nogc @safe const(string)[] aliases() nothrow const pure {
        return _aliases;
    }

    ///First level parents for this MIME type.
    @nogc @safe const(string)[] parents() nothrow const pure {
        return _parents;
    }

    /**
     * Get icon name.
     */
    @nogc @safe string icon() nothrow const pure {
        return _icon;
    }

    ///Set icon name.
    @nogc @safe string icon(string iconName) nothrow pure {
        _icon = iconName;
        return _icon;
    }

    /**
     * Get icon name.
     * The difference from icon property is that this function provides default icon name if no explicitly set.
     * The default form is MIME type name with '/' replaces with '-'.
     * Note: This function will allocate every time it's called if no icon explicitly set.
     */
    @safe string getIcon() nothrow const pure {
        if (_icon.length) {
            return _icon;
        } else {
            return defaultIconName(_name);
        }
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/mytype");
        assert(mimeType.icon.length == 0);
        assert(mimeType.getIcon() == "text-mytype");
        mimeType.icon = "mytype";
        assert(mimeType.getIcon() == "mytype");
        assert(mimeType.icon == "mytype");
    }

    /**
     * Get generic icon name.
     * Use this if the icon could not be found.
     */
    @nogc @safe string genericIcon() nothrow const pure {
        return _genericIcon;
    }

    ///Set generic icon name.
    @nogc @safe string genericIcon(string iconName) nothrow pure {
        _genericIcon = iconName;
        return _genericIcon;
    }

    /**
     * Get generic icon name.
     * The difference from genericIcon property is that this function provides default generic icon name if no explicitly set.
     * The default form is media part of MIME type name with '-x-generic' appended.
     * Note: This function will allocate every time it's called if no generic icon explicitly set.
     */
    @safe string getGenericIcon() nothrow const pure {
        if (_genericIcon.length) {
            return _genericIcon;
        } else {
            return defaultGenericIconName(_name);
        }
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/mytype");
        assert(mimeType.genericIcon.length == 0);
        assert(mimeType.getGenericIcon() == "text-x-generic");
        mimeType.genericIcon = "mytype";
        assert(mimeType.getGenericIcon() == "mytype");
        assert(mimeType.genericIcon == "mytype");
    }

    ///Get namespace uri for XML-based types.
    @nogc @safe string namespaceUri() nothrow const pure{
        return _namespaceUri;
    }

    ///Set namespace uri.
    @nogc @safe string namespaceUri(string uri) nothrow pure{
        _namespaceUri = uri;
        return _namespaceUri;
    }

    /**
     * Add alias for this MIME type.
     */
    @safe void addAlias(string alias_) nothrow pure {
        _aliases ~= alias_;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/html");
        mimeType.addAlias("application/html");
        mimeType.addAlias("text/x-html");
        assert(mimeType.aliases == ["application/html", "text/x-html"]);
        mimeType.clearAliases();
        assert(mimeType.aliases().empty);
    }

    /// Remove all aliases.
    @safe void clearAliases() nothrow pure {
        _aliases = null;
    }

    /**
     * Add parent type for this MIME type.
     */
    @safe void addParent(string parent) nothrow pure {
        _parents ~= parent;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/html");
        mimeType.addParent("text/xml");
        mimeType.addParent("text/plain");
        assert(mimeType.parents == ["text/xml", "text/plain"]);
        mimeType.clearParents();
        assert(mimeType.parents().empty);
    }

    /// Remove all parents.
    @safe void clearParents() nothrow pure {
        _parents = null;
    }

    /**
     * Add glob pattern for this MIME type.
     */
    @safe void addGlob(string pattern, uint weight = defaultGlobWeight, bool cs = false) nothrow pure {
        _globs ~= MimeGlob(pattern, weight, cs);
    }
    ///
    unittest
    {
        auto mimeType = new MimeType("image/jpeg");
        mimeType.addGlob("*.jpg");
        mimeType.addGlob(MimeGlob("*.jpeg"));
        assert(mimeType.globs() == [MimeGlob("*.jpg"), MimeGlob("*.jpeg")]);
        mimeType.clearGlobs();
        assert(mimeType.globs().empty);
    }

    ///ditto
    @safe void addGlob(MimeGlob mimeGlob) nothrow pure {
        _globs ~= mimeGlob;
    }

    deprecated("Use addGlob") alias addGlob addPattern;

    /// Remove all glob patterns.
    @safe void clearGlobs() nothrow pure {
        _globs = null;
    }

    deprecated("Use clearGlobs") alias clearGlobs clearPatterns;

    /**
     * Magic rules for this MIME type.
     * Returns: Array of $(D mime.magic.MimeMagic).
     */
    @nogc @safe auto magics() const nothrow pure {
        return _magics;
    }

    /**
     * Add magic rule.
     */
    @safe void addMagic(MimeMagic magic) nothrow pure {
        _magics ~= magic;
    }

    /**
     * Remove all magic rules.
     */
    @safe void clearMagic() nothrow pure {
        _magics = null;
    }

    /**
     * Treemagic rules for this MIME type.
     */
    @nogc @safe auto treeMagics() const nothrow pure {
        return _treemagics;
    }

    /**
     * Add treemagic rule.
     */
    @safe void addTreeMagic(TreeMagic magic) nothrow pure {
        _treemagics ~= magic;
    }

    /**
     * Remove all treemagic rules.
     */
    @safe void clearTreeMagic() nothrow pure {
        _treemagics = null;
    }

    /**
     * Create MimeType deep copy.
     */
    @safe MimeType clone() nothrow const pure {
        auto copy = new MimeType(this.name());
        copy.icon = this.icon();
        copy.genericIcon = this.genericIcon();
        copy.namespaceUri = this.namespaceUri();

        foreach(parent; this.parents()) {
            copy.addParent(parent);
        }

        foreach(aliasName; this.aliases()) {
            copy.addAlias(aliasName);
        }

        foreach(glob; this.globs()) {
            copy.addGlob(glob);
        }

        foreach(magic; this.magics()) {
            copy.addMagic(magic.clone());
        }

        foreach(magic; this.treeMagics()) {
            copy.addTreeMagic(magic.clone());
        }

        return copy;
    }

    ///
    unittest
    {
        auto origin = new MimeType("text/xml");
        origin.icon = "xml";
        origin.genericIcon = "text";
        origin.namespaceUri = "namespace";
        origin.addParent("text/plain");
        origin.addAlias("application/xml");
        origin.addGlob("<?xml");

        auto firstMagic = MimeMagic(50);
        firstMagic.addMatch(MagicMatch(MagicMatch.Type.string_, [0x01, 0x02]));
        origin.addMagic(firstMagic);

        auto secondMagic = MimeMagic(60);
        secondMagic.addMatch(MagicMatch(MagicMatch.Type.string_, [0x03, 0x04]));
        origin.addMagic(secondMagic);

        origin.addTreeMagic(TreeMagic(50));

        auto clone = origin.clone();
        assert(clone.name() == origin.name());
        assert(clone.icon() == origin.icon());
        assert(clone.genericIcon() == origin.genericIcon());
        assert(clone.namespaceUri() == origin.namespaceUri());
        assert(clone.parents() == origin.parents());
        assert(clone.aliases() == origin.aliases());
        assert(clone.globs() == origin.globs());
        assert(clone.magics().length == origin.magics().length);

        clone.clearTreeMagic();
        assert(origin.treeMagics().length == 1);

        origin.addParent("text/markup");
        assert(origin.parents() == ["text/plain", "text/markup"]);
        assert(clone.parents() == ["text/plain"]);
    }

private:
    string _name;
    string _icon;
    string _genericIcon;
    string[] _aliases;
    string[] _parents;
    string _namespaceUri;
    MimeGlob[] _globs;
    MimeMagic[] _magics;
    TreeMagic[] _treemagics;
}
