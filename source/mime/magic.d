module mime.magic;

import std.exception;
import mime.common;

/**
 * One of magic rules in magic definition. Represents <match> element in source XML.
 */
struct MagicMatch
{
    /**
     * Type of match value.
     */
    enum Type {
        string_, ///string
        host16,  ///16-bit value in host endian
        host32,  ///32-bit value in host endian
        big16,   ///16-bit value in big endian
        big32,   ///32-bit value in big endian
        little16, ///16-bit value in little endian
        little32, ///32-bit value in little endian
        byte_    ///single byte value
    }
    
    /**
     * Construct MagicMatch from type, value, mask, startOffset and rangeLength
     * Throws:
     *  Exception if value length does not match type.
     */
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
                enforce(value.length == 2, "value length must be 2 for given type");
                break;
            case Type.host32:
            case Type.big32:
            case Type.little32:
                enforce(value.length == 4, "value length must be 4 for given type");
                break;
        }
        _type = type;
        _value = value;
        _mask = mask;
        _startOffset = startOffset;
        _rangeLength = rangeLength;
    }
    
    /**
     * Type of match value.
     */
    @nogc @safe Type type() nothrow const {
        return _type;
    }
    
    /**
     * The offset into the file to look for a match.
     */
    @nogc @safe uint startOffset() nothrow const {
        return _startOffset;
    }
    @nogc @safe uint startOffset(uint offset) nothrow {
        _startOffset = offset;
        return _startOffset;
    }
    
    /**
     * The length of the region in the file to check.
     */
    @nogc @safe uint rangeLength() nothrow const {
        return _rangeLength;
    }
    @nogc @safe uint rangeLength(uint length) nothrow {
        _rangeLength = length;
        return _rangeLength;
    }
    
    /**
     * The value to compare the file contents with
     */
    @nogc @safe immutable(ubyte)[] value() nothrow const {
        return _value;
    }
    
    /**
     * Check if the rule has value mask.
     */
    @nogc @safe bool hasMask() nothrow const {
        return _mask.length != 0;
    }
    /**
     * The number to AND the value in the file with before comparing it to `value'
     * See_Also: value
     */
    @nogc @safe immutable(ubyte)[] mask() nothrow const {
        return _mask;
    }
    
    /**
     * Get match subrules
     * Returns: Array of child rules.
     */
    @nogc @safe auto submatches() nothrow const {
        return _submatches;
    }
    
    /**
     * Add subrule to the children of this rule.
     */
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

/**
 * Magic definition. Represents <magic> element in souce XML.
 */
struct MimeMagic
{
    /**
     * Constructor specifiyng priority for all contained rules.
     */
    @nogc @safe this(uint weight) {
        _weight = weight;
    }
    
    /**
     * Priority for all contained rules.
     */
    @nogc @safe uint weight() const nothrow {
        return _weight;
    }
    
    @nogc @safe uint weight(uint priority) nothrow {
        _weight = priority;
        return _weight;
    }
    
    /**
     * Get match rules
     * Returns: Array of MagicMatch elements.
     */
    auto matches() const nothrow {
        return _matches;
    }
    
    /**
     * Add top-level match rule.
     */
    void addMatch(MagicMatch match) nothrow {
        _matches ~= match;
    }
    
    /**
     * Indicates that magic matches read from less preferable paths must be discarded
     */
    @nogc @safe bool shouldDeleteMagic() nothrow const {
        return _deleteMagic;
    }
    
    @nogc @safe bool shouldDeleteMagic(bool shouldDelete) nothrow {
        _deleteMagic = shouldDelete;
        return _deleteMagic;
    }
    
private:
    uint _weight = defaultMatchWeight;
    MagicMatch[] _matches;
    bool _deleteMagic;
}
