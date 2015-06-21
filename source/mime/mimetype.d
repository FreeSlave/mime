module mime.mimetype;

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

struct MimeType
{   
    this(string name) {
        _name = name;
    }
    
    @nogc @safe string name() nothrow const {
        return _name;
    }
    
    @nogc @safe const(string)[] patterns() nothrow const {
        return null;
    }
    @nogc @safe bool globDeleteAll() nothrow const {
        return false;
    }
    
    //@nogc @safe const(MagicMatch)[] magicMatches() nothrow const;
    
    @nogc @safe bool magicDeleteAll() nothrow const {
        return false;
    }
    
    @nogc @safe const(string)[] aliases() nothrow const {
        return _aliases;
    }
    
    @nogc @safe const(string)[] parents() nothrow const {
        return _parents;
    }
    
    //@nogc @safe const(MimeComment)[] comments() nothrow const;
    @nogc @safe string acronym() nothrow const {
        return null;
    }
    @nogc @safe string expandedAcronym() nothrow const {
        return null;
    }
    
    @nogc @safe string iconName() nothrow const {
        return null;
    }
    
    @nogc @safe string genericIconName() nothrow const {
        return null;
    }
    
package:
    @safe void addAlias(string alias_) nothrow {
        _aliases ~= alias_;
    }
    
    @safe void addParent(string parent) nothrow {
        _parents ~= parent;
    }
    
private:
    string _name;
    string _icon;
    string _genericIcon;
    string[] _aliases;
    string[] _parents;
}
