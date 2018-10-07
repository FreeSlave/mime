/**
 * Parsing mime/magic files.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.magic;
public import mime.magic;
import mime.common;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.conv;
    import std.exception;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
    import mime.files.common;
}

///Exception thrown on parse errors while reading shared MIME database magic file.
final class MimeMagicFileException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
    }
}

///MIME type name and corresponding magic.
alias Tuple!(immutable(char)[], "mimeType", MimeMagic, "magic", bool, "deleteMagic") MagicEntry;

private @trusted MagicMatch parseMagicMatch(ref const(char)[] current, uint myIndent)
{
    enforce(current.length && current[0] == '>', "Expected '>' at the start of match rule");
    current = current[1..$];
    uint startOffset = parse!uint(current);
    enforce(current.length && current[0] == '=', "Expected '=' after start-offset");
    current = current[1..$];

    const(ubyte)[] value;
    enum noMagic = "__NOMAGIC__";
    if (current.length >= noMagic.length && current[0..noMagic.length] == noMagic) {
        value = cast(typeof(value))noMagic;
    } else {
        enforce(current.length >= 2, "Expected 2 bytes to read value length");
        ubyte[2] bigEndianLength;
        bigEndianLength[0] = cast(ubyte)current[0];
        bigEndianLength[1] = cast(ubyte)current[1];
        current = current[2..$];

        auto valueLength = bigEndianToNative!ushort(bigEndianLength);
        enforce(current.length >= valueLength, "Value is out of bounds");

        value = cast(typeof(value))(current[0..valueLength]);
    }

    current = current[value.length..$];

    typeof(value) mask;
    if (current.length && current[0] == '&') {
        current = current[1..$];
        enforce(current.length >= value.length, "Mask is out of bounds");
        mask = cast(typeof(value))(current[0..value.length]);
        current = current[value.length..$];
    }

    uint wordSize = 1;
    if (current.length && current[0] == '~') {
        current = current[1..$];
        wordSize = parse!uint(current);
    }

    uint rangeLength = 1;
    if (current.length && current[0] == '+') {
        current = current[1..$];
        rangeLength = parse!uint(current);
    }

    size_t charIndex;
    bool foundNewLine = false;
    for (charIndex = 0; charIndex < current.length; ++charIndex) {
        if (current[charIndex] == '\n') {
            current = current[charIndex+1..$];
            foundNewLine = true;
            break;
        }
    }

    enforce(foundNewLine, "Expected new line character after match rule definition");

    auto type = MagicMatch.Type.string_;

    //Not sure if this is right...
    if (wordSize == 2 && value.length == 2) {
        type = MagicMatch.Type.host16;
    } else if (wordSize == 4 && value.length == 4) {
        type = MagicMatch.Type.host32;
    }

    auto match = MagicMatch(type, value.idup, mask.idup, startOffset, rangeLength);

    //read sub rules
    while (current.length && current[0] != '[') {
        auto copy = current;
        uint indent = parseIndent(copy);
        if (indent > myIndent) {
            current = copy;
            MagicMatch submatch = parseMagicMatch(current, indent);
            match.addSubmatch(submatch);
        } else {
            break;
        }
    }

    return match;
}

/**
 * Reads magic file contents and push magic entries to sink.
 * Throws:
 *  $(D MimeMagicFileException) on error.
 */
void magicFileReader(OutRange)(const(void)[] data, OutRange sink) if (isOutputRange!(OutRange, MagicEntry))
{
    try {
        enum mimeMagic = "MIME-Magic\0\n";
        auto content = cast(const(char)[])data;
        if (!content.startsWith(mimeMagic)) {
            throw new Exception("Not mime magic file");
        }

        auto current = content[mimeMagic.length..$];

        while(current.length) {
            enforce(current[0] == '[', "Expected '[' at the start of magic section");
            current = current[1..$];

            auto result = findSplit(current[0..$], "]\n");
            enforce(result[1].length, "Could not find \"]\\n\"");
            current = result[2];

            auto sectionResult = findSplit(result[0], ":");
            enforce(sectionResult[1].length, "Priority and MIME type must be splitted by ':'");

            uint priority = parse!uint(sectionResult[0]);
            auto mimeType = sectionResult[2];

            auto magic = MimeMagic(priority);

            bool shouldDeleteMagic = false;
            while (current.length && current[0] != '[') {
                uint indent = parseIndent(current);

                MagicMatch match = parseMagicMatch(current, indent);
                if (isNoMagic(match.value)) {
                    shouldDeleteMagic = true;
                } else {
                    magic.addMatch(match);
                }
            }
            sink(MagicEntry(mimeType.idup, magic, shouldDeleteMagic));
        }
    } catch (Exception e) {
        throw new MimeMagicFileException(e.msg, e.file, e.line, e.next);
    }
}

///
unittest
{
    auto data =
        "MIME-Magic\0\n[60:text/x-diff]\n" ~
        ">0=__NOMAGIC__\n" ~
        "0>4=\x00\x02\x55\x40&\xff\xf0~2+8\n" ~
            "1>12=\x00\x04\x55\x40\xff\xf0~4+10\n";

    void sink(MagicEntry t) {
        assert(t.mimeType == "text/x-diff");
        assert(t.magic.weight == 60);
        assert(t.magic.matches.length == 1);
        assert(t.deleteMagic);

        auto match = t.magic.matches[0];
        assert(match.startOffset == 4);
        assert(match.value.length == 2);
        assert(match.mask.length == 2);
        assert(match.type == MagicMatch.Type.host16);
        assert(match.rangeLength == 8);
        assert(match.submatches.length == 1);

        auto submatch = match.submatches[0];
        assert(submatch.startOffset == 12);
        assert(submatch.value.length == 4);
        assert(!submatch.hasMask());
        assert(submatch.type == MagicMatch.Type.host32);
        assert(submatch.rangeLength == 10);
    }
    magicFileReader(data, &sink);

    void emptySink(MagicEntry t) {

    }
    assertThrown!MimeMagicFileException(magicFileReader("MIME-wrong-magic", &emptySink));

}
