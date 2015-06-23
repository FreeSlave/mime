module mime.database.magic;

import mime.common;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.conv;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias Tuple!(uint, "ident", uint, "startOffset", ushort, "valueLength", string, "value", string, "mask", uint, "wordSize", uint, "rangeLength") MagicLine;

private struct MagicRange(Range)
{
    this(Range byLine) {
        _byLine = byLine;
    }
    
    @property auto front() {
        string header = _byLine.front;
        if (!header.empty && header.startsWith("[")) {
            auto result = findSplitBefore(header[1..$], "]");
            if (!result[1].empty) {
                auto sectionResult = findSplit(result[0], ":");
                if (!sectionResult[1].empty) {
                    uint priority = parse!uint(sectionResult[0]);
                    auto mimeType = sectionResult[2];
                    _byLine.popFront();
                    return tuple!("priority", "mimeType", "line")
                                 (priority, mimeType, _byLine.until!(s => s.startsWith("[")).map!(s => parseMagicLine(s)) );
                }
            }
        }
        throw new Exception("Error parsing magic section");
    }
    
    void popFront() {
        //make sure input range is in the end of the section
        auto untilLine = _byLine.until!(s => s.startsWith("["));
        while(!untilLine.empty) {
            untilLine.popFront();
        }
    }
    
    @property bool empty() {
        return _byLine.empty();
    }
    
private:
    MagicLine parseMagicLine(string str) {
        //Ugly code!
        
        auto strSplit = findSplit(str, ">");
        if (strSplit[1].empty) {
            throw new Exception("Missing '>' character in magic line");
        }
        
        auto indent = parse!uint(strSplit[0]);
        
        strSplit = findSplit(strSplit[2], "=");
        if (strSplit[1].empty) {
            throw new Exception("Missing '=' character in magic line");
        }
        auto startOffset = parse!uint(strSplit[0]);
        
        auto valueStr = strSplit[2];
        
        if (valueStr.length >= 2) {
            ubyte[2] bigEndianLength;
            bigEndianLength[0] = cast(ubyte)valueStr[0];
            bigEndianLength[1] = cast(ubyte)valueStr[1];
            valueStr = valueStr[2..$];
            auto valueLength = bigEndianToNative!ushort(bigEndianLength);
            if (valueStr.length >= valueLength) {
                auto value = valueStr[0..valueLength];
                valueStr = valueStr[valueLength..$];
                
                string mask;
                uint wordSize;
                uint rangeLength;
                if (!valueStr.empty && valueStr.front == '&') {
                    valueStr.popFront();
                    if (valueStr.length >= valueLength) {
                        mask = valueStr[0..valueLength];
                    } else {
                        throw new Exception("Failed to read mask in magic line");
                    }
                }
                if (!valueStr.empty && valueStr.front == '~') {
                    valueStr.popFront();
                    wordSize = parse!uint(valueStr);
                }
                if (!valueStr.empty && valueStr.front == '+') {
                    valueStr.popFront();
                    rangeLength = parse!uint(valueStr);
                }
                return MagicLine(indent, startOffset, valueLength, value, mask, wordSize, rangeLength);
                //actually should check if the rest of string has symbols and ignore the whole line in this case.
            } else {
                throw new Exception("Failed to read value in magic line");
            }
        } else {
            throw new Exception("Failed to read value length in magic line");
        }
        
    }
    
    Range _byLine;
}

private auto magicRange(Range)(Range byLine) {
    return MagicRange!Range(byLine);
}

@trusted auto magicFileReader(Range)(Range byLine) if(is(ElementType!Range : string))
{
    if (byLine.empty || !equal(byLine.front, "MIME-Magic\0\n")) {
        throw new Exception("Not mime magic file");
    }
    byLine.popFront();
    return magicRange(byLine);
}

@trusted auto magicFileReader(string fileName) {
    return magicFileReader(fileReader(fileName));
}

