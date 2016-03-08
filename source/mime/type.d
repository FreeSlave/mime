/**
 * Struct represented single MIME type.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.type;

import mime.common;
public import mime.magic;

private {
    import std.algorithm;
    import std.range;
}

/**
 * Glob pattern for detecting MIME type of file by name.
 */
struct MimePattern
{
    @nogc @safe this(string glob, uint priority = defaultGlobWeight, bool cs = false) nothrow {
        pattern = glob;
        weight = priority;
        caseSensitive = cs;
    }
    
    ///Glob pattern as string.
    string pattern;
    ///Priority of pattern.
    uint weight;
    ///Tells whether the pattern should be considered case sensitive or not.
    bool caseSensitive;
    
    ///Member version of static isLiteral. Uses pattern as argument.
    @nogc @safe bool isLiteral() nothrow pure const {
        return isLiteral(pattern);
    }
    ///
    unittest
    {
        auto mimePattern = MimePattern("Makefile");
        assert(mimePattern.isLiteral());
    }
    
    ///Member version of static isSuffix. Uses pattern as argument.
    @nogc @safe bool isSuffix() nothrow pure const {
        return isSuffix(pattern);
    }
    ///
    unittest
    {
        auto mimePattern = MimePattern("*.txt");
        assert(mimePattern.isSuffix());
    }
    
    ///Member version of static isGenericGlob. Uses pattern as argument.
    @nogc @safe bool isGenericGlob() nothrow pure const {
        return isGenericGlob(pattern);
    }
    ///
    unittest
    {
        auto mimePattern = MimePattern("lib*.so.[0-9]");
        assert(mimePattern.isGenericGlob());
    }
    
    private @nogc @safe static bool isGlobSymbol(char c) nothrow pure {
        return c == '*' || c == '[' || c == '?';
    }
    
    /**
     * Check if glob is literal, i.e. does not have special glob match characters.
     */
    @nogc @safe static bool isLiteral(string glob) nothrow pure {
        if (glob.length == 0) {
            return false;
        }
        for (size_t i=0; i<glob.length; ++i) {
            if (isGlobSymbol(glob[i])) {
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
     * Check if glob is suffix, i.e. starts with '*' and does not have special glob match characters in the rest of pattern.
     */
    @nogc @safe static bool isSuffix(string glob) nothrow pure {
        if (glob.length > 1 && glob[0] == '*') {
            for (size_t i=1; i<glob.length; ++i) {
                if (isGlobSymbol(glob[i])) {
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
     * Check if glob is some glob pattern other than literal and suffix.
     */
    @nogc @safe static bool isGenericGlob(string glob) nothrow pure {
        return glob.length > 0 && !isLiteral(glob) && !isSuffix(glob);
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

/**
 * Represents single MIME type.
 */
final class MimeType
{   
    /**
     * Create MIME type with name.
     * Name should be given in the form of media/subtype.
     */
    @trusted this(string name) nothrow {
        _name = name;
    }
    
    ///The name of MIME type.
    @nogc @safe string name() nothrow const {
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
    @nogc @safe string name(string typeName) nothrow {
        _name = typeName;
        return _name;
    }
    
    ///Array of MIME glob patterns applied to this MIME type.
    @nogc @safe const(MimePattern)[] patterns() nothrow const {
        return _patterns;
    }
    
    ///Aliases to this MIME type.
    @nogc @safe const(string)[] aliases() nothrow const {
        return _aliases;
    }
    
    ///First level parents for this MIME type.
    @nogc @safe const(string)[] parents() nothrow const {
        return _parents;
    }
    
    /**
     * Get icon namee.
     */
    @nogc @safe string icon() nothrow const {
        return _icon;
    }
    
    ///Set icon name.
    @nogc @safe string icon(string iconName) nothrow {
        _icon = iconName;
        return _icon;
    }
    
    /**
     * Get icon name.
     * The difference from icon property is that this function provides default icon name if no explicitly set.
     * The default form is MIME type name with '/' replaces with '-'.
     * Note: This function will allocate every time it's called if no icon explicitly set.
     */
    @safe string getIcon() nothrow const {
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
    @nogc @safe string genericIcon() nothrow const {
        return _genericIcon;
    }
    
    ///Set generic icon name.
    @nogc @safe string genericIcon(string iconName) nothrow {
        _genericIcon = iconName;
        return _genericIcon;
    }
    
    /**
     * Get generic icon name.
     * The difference from genericIcon property is that this function provides default generic icon name if no explicitly set.
     * The default form is media part of MIME type name with '-x-generic' appended.
     * Note: This function will allocate every time it's called if no generic icon explicitly set.
     */
    @safe string getGenericIcon() nothrow const {
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
    @nogc @safe string namespaceUri() nothrow const {
        return _namespaceUri;
    }
    
    ///Set namespace uri.
    @nogc @safe string namespaceUri(string uri) nothrow {
        _namespaceUri = uri;
        return _namespaceUri;
    }
    
    /**
     * Add alias for this MIME type.
     */
    @safe void addAlias(string alias_) nothrow {
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
    @safe void clearAliases() nothrow {
        _aliases = null;
    }
    
    /**
     * Add parent type for this MIME type.
     */
    @safe void addParent(string parent) nothrow {
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
    @safe void clearParents() nothrow {
        _parents = null;
    }
    
    /**
     * Add glob pattern for this MIME type.
     */
    @safe void addPattern(string pattern, uint weight = defaultGlobWeight, bool cs = false) nothrow {
        _patterns ~= MimePattern(pattern, weight, cs);
    }
    ///
    unittest
    {
        auto mimeType = new MimeType("image/jpeg");
        mimeType.addPattern("*.jpg");
        mimeType.addPattern(MimePattern("*.jpeg"));
        assert(mimeType.patterns() == [MimePattern("*.jpg"), MimePattern("*.jpeg")]);
        mimeType.clearPatterns();
        assert(mimeType.patterns().empty);
    }
    
    ///ditto
    @safe void addPattern(MimePattern mimePattern) nothrow {
        _patterns ~= mimePattern;
    }
    
    /// Remove all glob patterns.
    @safe void clearPatterns() nothrow {
        _patterns = null;
    }
    
    @nogc @safe auto magics() const nothrow {
        return _magics;
    }
    
    @safe void addMagic(MimeMagic magic) nothrow {
        _magics ~= magic;
    }
    
    @safe void clearMagic() nothrow {
        _magics = null;
    }
    
private:
    string _name;
    string _icon;
    string _genericIcon;
    string[] _aliases;
    string[] _parents;
    string _namespaceUri;
    MimePattern[] _patterns;
    MimeMagic[] _magics;
}
