/**
 * Parsing mime/magic files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.files.magic;
import mime.magic;
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
}

alias Tuple!(immutable(char)[], "mimeType", MimeMagic, "magic") MagicEntry;

private MagicMatch parseMagicMatch(ref immutable(char)[] current, uint myIndent)
{
    enforce(current.length && current[0] == '>', "Expected '>' at the start of match rule");
    current = current[1..$];
    uint startOffset = parse!uint(current);
    enforce(current.length && current[0] == '=', "Expected '=' after start-offset");
    current = current[1..$];
    
    enforce(current.length >= 2, "Expected 2 bytes to read value length");
    ubyte[2] bigEndianLength;
    bigEndianLength[0] = cast(ubyte)current[0];
    bigEndianLength[1] = cast(ubyte)current[1];
    current = current[2..$];
    
    auto valueLength = bigEndianToNative!ushort(bigEndianLength);
    enforce(current.length >= valueLength, "Value is out of bounds");
    
    auto value = cast(immutable(ubyte)[])(current[0..valueLength]);
    current = current[valueLength..$];
    
    
    typeof(value) mask;
    if (current.length && current[0] == '&') {
        current = current[1..$];
        enforce(current.length >= valueLength, "Mask is out of bounds");
        mask = cast(typeof(value))(current[0..valueLength]);
        current = current[valueLength..$];
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
    
    auto type = MagicMatch.Type.byte_;
    if (wordSize == 2) {
        type = MagicMatch.Type.big16;
    } else if (wordSize == 4) {
        type = MagicMatch.Type.big32;
    }
    
    auto match = MagicMatch(type, value, mask, startOffset, rangeLength);
    
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

private uint parseIndent(ref immutable(char)[] current)
{
    enforce(current.length);
    uint indent = 0;
    
    if (current[0] != '>') {
        indent = parse!uint(current);
    }
    return indent;
}

/**
 * Reads magic file contents and push magic entries to sink.
 */
@trusted void magicFileReader(OutRange)(immutable(void)[] data, OutRange sink) if (isOutputRange!(OutRange, MagicEntry))
{
    enum mimeMagic = "MIME-Magic\0\n";
    auto content = cast(immutable(char)[])data;
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
        
        while (current.length && current[0] != '[') {
            uint indent = parseIndent(current);
            
            MagicMatch match = parseMagicMatch(current, indent);
            magic.addMatch(match);
        }
        sink(MagicEntry(mimeType, magic));
    }
}

