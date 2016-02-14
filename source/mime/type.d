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
    ///Glob pattern as string.
    string pattern;
    ///Priority of pattern.
    uint weight;
    ///Tells whether the pattern should be considered case sensitive or not.
    bool caseSensitive;
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
    
    ///First level parents for  this MIME type.
    @nogc @safe const(string)[] parents() nothrow const {
        return _parents;
    }
    
    /**
     * Get icon name for the MIME type. 
     * The default form is MIME type name with '/' replaces with '-'.
     */
    @nogc @safe string icon() nothrow const {
        return _icon;
    }
    
    ///Set icon name for MIME type.
    @nogc @safe string icon(string iconName) nothrow {
        _icon = iconName;
        return _icon;
    }
    
    /**
     * Get generic icon name for the MIME type. 
     * The default form is media part of MIME type name with '-x-generic' appended.
     * Use this if the icon could not be found.
     */
    @nogc @safe string genericIcon() nothrow const {
        return _genericIcon;
    }
    
    ///Set generic icon name for MIME type.
    @nogc @safe string genericIcon(string iconName) nothrow {
        _genericIcon = iconName;
        return _genericIcon;
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
    
    @safe void addAlias(string alias_) nothrow {
        _aliases ~= alias_;
    }
    
    @safe void addParent(string parent) nothrow {
        _parents ~= parent;
    }
    
    @safe void addPattern(string pattern, uint weight, bool cs) nothrow {
        _patterns ~= MimePattern(pattern, weight, cs);
    }
    
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
