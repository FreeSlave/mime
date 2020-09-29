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

import std.typecons : Tuple;

private {
    import std.algorithm.searching : canFind;
    import std.range;
}

///
alias Tuple!(string, "namespaceURI", string, "localName") XMLnamespace;

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

    ///Descriptive comment of MIME type.
    @nogc @safe string displayName() nothrow const pure {
        return _displayName;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/markdown");
        mimeType.displayName = "Markdown document";
        assert(mimeType.displayName == "Markdown document");
    }

    ///Set descriptive comment.
    @nogc @safe string displayName(string comment) nothrow pure {
        _displayName = comment;
        return _displayName;
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

    ///Get XML namespaces associated with this XML-based MIME type.
    @nogc @safe const(XMLnamespace)[] XMLnamespaces() nothrow const pure {
        return _XMLnamespaces;
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

    ///Add XML namespace.
    @safe void addXMLnamespace(string namespaceURI, string localName) nothrow pure {
        addXMLnamespace(XMLnamespace(namespaceURI, localName));
    }

    ///ditto
    @safe void addXMLnamespace(XMLnamespace namespace) nothrow pure {
        if (!_XMLnamespaces.canFind(namespace))
            _XMLnamespaces ~= namespace;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/html");
        mimeType.addXMLnamespace("http://www.w3.org/1999/xhtml", "html");
        assert(mimeType.XMLnamespaces == [XMLnamespace("http://www.w3.org/1999/xhtml", "html")]);
        mimeType.clearXMLnamespaces();
        assert(mimeType.XMLnamespaces().empty);
    }

    /// Remove all XML namespaces.
    @safe void clearXMLnamespaces() nothrow pure {
        _XMLnamespaces = null;
    }

    /**
     * Add alias for this MIME type. Adding a duplicate does nothing.
     */
    @safe void addAlias(string alias_) nothrow pure {
        if (!_aliases.canFind(alias_))
            _aliases ~= alias_;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/html");
        mimeType.addAlias("application/html");
        mimeType.addAlias("text/x-html");
        mimeType.addAlias("application/html");
        assert(mimeType.aliases == ["application/html", "text/x-html"]);
        mimeType.clearAliases();
        assert(mimeType.aliases().empty);
    }

    /// Remove all aliases.
    @safe void clearAliases() nothrow pure {
        _aliases = null;
    }

    /**
     * Add parent type for this MIME type. Adding a duplicate does nothing.
     */
    @safe void addParent(string parent) nothrow pure {
        if (!_parents.canFind(parent))
            _parents ~= parent;
    }

    ///
    unittest
    {
        auto mimeType = new MimeType("text/html");
        mimeType.addParent("text/xml");
        mimeType.addParent("text/plain");
        mimeType.addParent("text/xml");
        assert(mimeType.parents == ["text/xml", "text/plain"]);
        mimeType.clearParents();
        assert(mimeType.parents().empty);
    }

    /// Remove all parents.
    @safe void clearParents() nothrow pure {
        _parents = null;
    }

    /**
     * Add glob pattern for this MIME type. Adding a duplicate does nothing.
     */
    @safe void addGlob(string pattern, uint weight = defaultGlobWeight, bool cs = false) nothrow pure {
        addGlob(MimeGlob(pattern, weight, cs));
    }
    ///
    unittest
    {
        auto mimeType = new MimeType("image/jpeg");
        mimeType.addGlob("*.jpg");
        mimeType.addGlob(MimeGlob("*.jpeg"));
        mimeType.addGlob("*.jpg");
        assert(mimeType.globs() == [MimeGlob("*.jpg"), MimeGlob("*.jpeg")]);
        mimeType.clearGlobs();
        assert(mimeType.globs().empty);
    }

    ///ditto
    @safe void addGlob(MimeGlob mimeGlob) nothrow pure {
        if (!_globs.canFind(mimeGlob))
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
        copy.displayName = this.displayName();
        copy.deleteGlobs = this.deleteGlobs;
        copy.deleteMagic = this.deleteMagic;

        foreach(namespace; this.XMLnamespaces()) {
            copy.addXMLnamespace(namespace);
        }

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
        origin.displayName = "XML document";
        origin.addXMLnamespace(XMLnamespace("http://www.w3.org/1999/xhtml", "html"));
        origin.addParent("text/plain");
        origin.addAlias("application/xml");
        origin.addGlob("*.xml");

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
        assert(clone.XMLnamespaces() == origin.XMLnamespaces());
        assert(clone.displayName() == origin.displayName());
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

    /**
     * Whether to discard globs parsed from a less preferable directory. Used in merges.
     * See_Also: $(D mime.type.mergeMimeTypes)
     */
    @nogc @safe bool deleteGlobs() nothrow const pure
    {
        return _deleteGlobs;
    }
    ///Setter
    @nogc @safe bool deleteGlobs(bool clearGlobs) nothrow pure
    {
        _deleteGlobs = clearGlobs;
        return clearGlobs;
    }

    /**
     * Whether to discard magic matches parsed from a less preferable directory. Used in merges.
     * See_Also: $(D mime.type.mergeMimeTypes)
     */
    @nogc @safe bool deleteMagic() nothrow const pure
    {
        return _deleteMagic;
    }
    ///Setter
    @nogc @safe bool deleteMagic(bool clearMagic) nothrow pure
    {
        _deleteMagic = clearMagic;
        return clearMagic;
    }

private:
    string _name;
    string _icon;
    string _genericIcon;
    string[] _aliases;
    string[] _parents;
    XMLnamespace[] _XMLnamespaces;
    MimeGlob[] _globs;
    MimeMagic[] _magics;
    TreeMagic[] _treemagics;
    string _displayName;
    bool _deleteGlobs;
    bool _deleteMagic;
}

private @safe void checkNamesEqual(scope const(MimeType) origin, scope const(MimeType) additive) pure
{
    import std.exception : enforce;
    enforce(origin.name == additive.name, "Can't merge MIME types with different names");
}

/**
 * In-place version of $(D mime.type.mergeMimeTypes)
 * See_Also: $(D mime.type.mergeMimeTypes)
 */
@safe void mergeMimeTypesInPlace(MimeType origin, const(MimeType) additive) pure
{
    checkNamesEqual(origin, additive);
    if (additive.displayName.length)
        origin.displayName = additive.displayName;
    if (additive.icon.length)
        origin.icon = additive.icon;
    if (additive.genericIcon.length)
        origin.genericIcon = additive.genericIcon;
    if (additive.deleteGlobs)
        origin.clearGlobs();
    if (additive.deleteMagic)
        origin.clearMagic();

    foreach(namespace; additive.XMLnamespaces()) {
        origin.addXMLnamespace(namespace);
    }
    foreach(parent; additive.parents()) {
        origin.addParent(parent);
    }
    foreach(aliasName; additive.aliases()) {
        origin.addAlias(aliasName);
    }
    foreach(glob; additive.globs()) {
        origin.addGlob(glob);
    }
    foreach(magic; additive.magics()) {
        origin.addMagic(magic.clone());
    }
    foreach(magic; additive.treeMagics()) {
        origin.addTreeMagic(magic.clone());
    }
}

/**
 * Merge MIME types definitions parsed from different mime/ directories.
 * Params:
 *  origin = MIME type definition that was read from a less preferable mime/ directory.
 *  additive = MIME type definition override from a more preferable mime/ directory.
 * Throws: $(B Exception) when trying to merge MIME types with different names.
 * See_Also: $(D mime.type.mergeMimeTypesInPlace)
 */
@safe MimeType mergeMimeTypes(const(MimeType) origin, const(MimeType) additive) pure
{
    checkNamesEqual(origin, additive);
    MimeType clone = origin.clone();
    mergeMimeTypesInPlace(clone, additive);
    return clone;
}

///
unittest
{
    import std.string : representation;
    import std.exception : assertThrown;

    MimeType mimeType1 = new MimeType("text/plain");
    MimeType mimeType2 = new MimeType("text/xml");

    assertThrown(mergeMimeTypes(mimeType1, mimeType2));

    mimeType1.name = "text/html";
    mimeType2.name = mimeType1.name;

    mimeType1.addGlob("*.htm");
    MimeMagic magic1;
    magic1.addMatch(MagicMatch(MagicMatch.Type.string_, "<HTML".representation));
    mimeType1.addMagic(magic1);

    mimeType2.addAlias("application/html");
    mimeType2.addParent("text/xml");
    mimeType2.addXMLnamespace("http://www.w3.org/1999/xhtml", "html");
    mimeType2.deleteGlobs = true;
    mimeType2.deleteMagic = true;
    mimeType2.icon = "application-html";
    mimeType2.addGlob("*.html");
    MimeMagic magic2;
    magic2.addMatch(MagicMatch(MagicMatch.Type.string_, "<html".representation));
    mimeType2.addMagic(magic2);

    auto mimeType = mergeMimeTypes(mimeType1, mimeType2);
    assert(mimeType.name == mimeType1.name);
    assert(mimeType.aliases == ["application/html"]);
    assert(mimeType.parents == ["text/xml"]);
    assert(mimeType.XMLnamespaces == [XMLnamespace("http://www.w3.org/1999/xhtml", "html")]);
    assert(mimeType.globs == [MimeGlob("*.html")]);
    assert(mimeType.icon == "application-html");
    assert(mimeType.magics.length == 1);
    assert(mimeType.magics[0].matches[0].value == "<html");
}
