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
        this.name = name;
    }
    
    @nogc @safe string name() nothrow const {
        return _name;
    }
    
    @safe string name(string newName) nothrow {
        return _name = newName;
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
        return null;
    }
    
    @nogc @safe const(string)[] subclassOf() nothrow const {
        return null;
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
    
private:
    string _name;
    string _icon;
    string _genericIcon;
}
