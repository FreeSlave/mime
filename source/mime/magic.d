module mime.magic;

import std.exception;

private {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

struct MagicMatch
{
    enum Type {
        string_, 
        host16, 
        host32, 
        big16, 
        big32, 
        little16, 
        little32, 
        byte_
    }
    
    @safe this(Type type, immutable(ubyte)[] value, immutable(ubyte)[] mask = null, uint startOffset = 0, uint rangeLength = 1)
    {
        if (mask.length) {
            enforce(value.length == mask.length, "value and mask lengths must be equal");
        }
        final switch(type) {
            case Type.string_:
            case Type.byte_:
                break;
            case Type.host16:
            case Type.big16:
            case Type.little16:
                enforce(value.length % 2 == 0, "value length must be multiple of 2 for given type");
                break;
            case Type.host32:
            case Type.big32:
            case Type.little32:
                enforce(value.length % 4 == 0, "value length must be multiple of 4 for given type");
                break;
        }
        
        _value = value;
        _mask = mask;
    }
    
    @nogc @safe Type type() nothrow const {
        return _type;
    }
    
    @nogc @safe uint startOffset() nothrow const {
        return _startOffset;
    }
    @nogc @safe uint startOffset(uint offset) nothrow {
        _startOffset = offset;
        return _startOffset;
    }
    
    @nogc @safe uint rangeLength() nothrow const {
        return _rangeLength;
    }
    @nogc @safe uint rangeLength(uint length) nothrow {
        _rangeLength = length;
        return _rangeLength;
    }
    
    @nogc @safe immutable(ubyte)[] value() nothrow const {
        return _value;
    }
    
    @nogc @safe bool hasMask() nothrow const {
        return _mask.length != 0;
    }
    @nogc @safe immutable(ubyte)[] mask() nothrow const {
        return _mask;
    }
    
    @nogc @safe auto submatches() nothrow const {
        return _submatches;
    }
    
    @safe void addSubmatch(MagicMatch match) nothrow {
        _submatches ~= match;
    }
    
private:
    Type _type;
    uint _startOffset;
    uint _rangeLength;
    immutable(ubyte)[] _value;
    immutable(ubyte)[] _mask;
    
    MagicMatch[] _submatches;
}

struct MimeMagic
{
    @nogc @safe this(uint weight) {
        _weight = weight;
    }
    
    @nogc @safe uint weight() const nothrow {
        return _weight;
    }
    
    @nogc @safe uint weight(uint priority) nothrow {
        _weight = priority;
        return _weight;
    }
    
    auto matches() const nothrow {
        return _matches;
    }
    
    void addMatch(MagicMatch match) nothrow {
        _matches ~= match;
    }
    
    @nogc @safe bool shouldDeleteMagic() nothrow const {
        return _deleteMagic;
    }
    
    @nogc @safe bool shouldDeleteMagic(bool shouldDelete) nothrow {
        _deleteMagic = shouldDelete;
        return _deleteMagic;
    }
    
private:
    uint _weight;
    MagicMatch[] _matches;
    bool _deleteMagic;
}
