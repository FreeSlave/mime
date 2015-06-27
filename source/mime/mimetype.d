module mime.mimetype;

private {
    import std.algorithm;
    import std.range;
}

// struct MagicMatch
// {
//     enum Type {
//         string_, 
//         host16, 
//         host32, 
//         big16, 
//         big32, 
//         little16, 
//         little32, 
//         byte_
//     }
//     
//     @nogc @safe Type type() nothrow const;
//     @nogc @safe Tuple!(uint, uint) offset() nothrow const;
//     
//     @nogc @safe auto value() nothrow const;
//     
//     @nogc @safe bool hasMask() nothrow const;
//     @nogc @safe auto mask() nothrow const;
// }
// 
// struct MimeComment
// {
//     @nogc @safe string text() nothrow const;
//     @nogc @safe string locale() nothrow const;
// }

struct MimePattern
{
    string pattern;
    uint weight;
    bool caseSensitive;
}

struct MimeType
{   
    @trusted this(string name) nothrow {
        _name = name;
        _icon = name.replace("/", "-");
        auto topLevel = name.findSplit("/")[0];
        _genericIcon = topLevel ~ "-x-generic";
    }
    
    @nogc @safe string name() nothrow const {
        return _name;
    }
    
    @nogc @safe const(MimePattern)[] patterns() nothrow const {
        return _patterns;
    }
    
    @nogc @safe const(string)[] aliases() nothrow const {
        return _aliases;
    }
    
    @nogc @safe const(string)[] parents() nothrow const {
        return _parents;
    }
    
    @nogc @safe string icon() nothrow const {
        return _icon;
    }
    
    @nogc @safe string icon(string iconName) nothrow {
        _icon = iconName;
        return _icon;
    }
    
    @nogc @safe string genericIcon() nothrow const {
        return _genericIcon;
    }
    
    @nogc @safe string genericIcon(string iconName) nothrow {
        _genericIcon = iconName;
        return _genericIcon;
    }
    
    @nogc @safe string namespaceUri() nothrow const {
        return _namespaceUri;
    }
    
    @nogc @safe string namespaceUri(string uri) nothrow {
        _namespaceUri = uri;
        return _namespaceUri;
    }
    
    @nogc @safe string localName() nothrow const {
        return _localName;
    }
    
    @nogc @safe string localName(string name) nothrow {
        _localName = name;
        return _localName;
    }
    
package:
    @safe void addAlias(string alias_) nothrow {
        _aliases ~= alias_;
    }
    
    @safe void addParent(string parent) nothrow {
        _parents ~= parent;
    }
    
    @safe void addPattern(string pattern, uint weight, bool cs) nothrow {
        _patterns ~= MimePattern(pattern, weight, cs);
    }
    
private:
    string _name;
    string _icon;
    string _genericIcon;
    string[] _aliases;
    string[] _parents;
    string _namespaceUri;
    string _localName;
    MimePattern[] _patterns;
}
