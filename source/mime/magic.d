/**
 * MIME magic rules object representation.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.magic;

import std.exception;
import mime.common;

/**
 * One of magic rules in magic definition. Represents &lt;match&gt; element in source XML.
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
     *  $(B Exception) if value length does not match type.
     */
    @safe this(Type type, immutable(ubyte)[] value, immutable(ubyte)[] mask = null, uint startOffset = 0, uint rangeLength = 1) pure
    {
        if (mask.length) {
            enforce(value.length == mask.length, "value and mask lengths must be equal");
        }
        import std.conv : text;
        final switch(type) {
            case Type.string_:
            case Type.byte_:
                break;
            case Type.host16:
            case Type.big16:
            case Type.little16:
                enforce(value.length == 2, text("value length must be 2 for ", type, " type"));
                break;
            case Type.host32:
            case Type.big32:
            case Type.little32:
                enforce(value.length == 4, text("value length must be 4 for ", type, " type"));
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
    @nogc @safe Type type() nothrow const pure {
        return _type;
    }

    /**
     * The offset into the file to look for a match.
     */
    @nogc @safe uint startOffset() nothrow const pure {
        return _startOffset;
    }
    @nogc @safe uint startOffset(uint offset) nothrow pure {
        _startOffset = offset;
        return _startOffset;
    }

    /**
     * The length of the region in the file to check.
     */
    @nogc @safe uint rangeLength() nothrow const pure {
        return _rangeLength;
    }
    @nogc @safe uint rangeLength(uint length) nothrow pure {
        _rangeLength = length;
        return _rangeLength;
    }

    /**
     * The value to compare the file contents with
     */
    @nogc @safe immutable(ubyte)[] value() nothrow const pure {
        return _value;
    }

    /**
     * Check if the rule has value mask.
     */
    @nogc @safe bool hasMask() nothrow const pure {
        return _mask.length != 0;
    }
    /**
     * The number to AND the value in the file with before comparing it to $(D value)
     * See_Also: $(D value)
     */
    @nogc @safe immutable(ubyte)[] mask() nothrow const pure {
        return _mask;
    }

    /**
     * Get match subrules
     * Returns: Array of child rules.
     */
    @nogc @safe auto submatches() nothrow const pure {
        return _submatches;
    }

    package @nogc @safe auto submatches() nothrow pure {
        return _submatches;
    }

    /**
     * Add subrule to the children of this rule.
     */
    @safe void addSubmatch(MagicMatch match) nothrow pure{
        _submatches ~= match;
    }

    package @trusted MagicMatch clone() const nothrow pure {
        MagicMatch copy;
        copy._type = this._type;
        copy._value = this._value;
        copy._mask = this._mask;
        copy._startOffset = this._startOffset;
        copy._rangeLength = this._rangeLength;

        foreach(match; _submatches) {
            copy.addSubmatch(match.clone());
        }
        return copy;
    }

    unittest
    {
        auto origin = MagicMatch(MagicMatch.Type.string_, [0x01, 0x02]);
        origin.addSubmatch(MagicMatch(MagicMatch.Type.string_, [0x03, 0x04, 0x05]));
        origin.addSubmatch(MagicMatch(MagicMatch.Type.string_, [0x06, 0x07]));

        const corigin = origin;
        assert(corigin.submatches().length == 2);

        auto shallow = origin;
        shallow.submatches()[0].startOffset = 4;
        assert(origin.submatches()[0].startOffset() == 4);

        auto clone = origin.clone();
        clone.submatches()[1].rangeLength = 3;
        assert(origin.submatches()[1].rangeLength() == 1);
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
 * Magic definition. Represents &lt;magic&gt; element in souce XML.
 */
struct MimeMagic
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
     * Get match rules
     * Returns: Array of $(D MagicMatch) elements.
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
    @safe void addMatch(MagicMatch match) nothrow pure {
        _matches ~= match;
    }

    package @trusted MimeMagic clone() const nothrow pure {
        auto copy = MimeMagic(this.weight());
        foreach(match; _matches) {
            copy.addMatch(match.clone());
        }
        return copy;
    }

    unittest
    {
        auto origin = MimeMagic(60);
        origin.addMatch(MagicMatch(MagicMatch.Type.string_, [0x01, 0x02]));
        origin.addMatch(MagicMatch(MagicMatch.Type.string_, [0x03, 0x04, 0x05]));

        auto shallow = origin;
        shallow.matches()[0].startOffset = 4;
        assert(origin.matches()[0].startOffset() == 4);

        const corigin = origin;
        assert(corigin.matches().length == 2);

        auto clone = origin.clone();
        clone.weight = 50;
        assert(origin.weight == 60);
        clone.matches()[1].rangeLength = 3;
        assert(origin.matches()[1].rangeLength() == 1);
    }

private:
    uint _weight = defaultMatchWeight;
    MagicMatch[] _matches;
}
