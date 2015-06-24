module mime.database.magic;

import mime.common;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.conv;
    import std.file;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

alias Tuple!(uint, "indent", uint, "startOffset", ushort, "valueLength", const(char)[], "value", const(char)[], "mask", uint, "wordSize", uint, "rangeLength") MagicLine;


private struct MagicRange
{
    this(const(char)[] content) {
        _content = content;
    }
    
    @property auto front() {
        if (_content.startsWith("[")) {
            _content = _content[1..$];
            
            auto result = findSplit(_content[0..$], "]\n");
            if (!result[1].empty) {
                _content = result[2];
                
                auto sectionResult = findSplit(result[0], ":");
                if (!sectionResult[1].empty) {
                    uint priority = parse!uint(sectionResult[0]);
                    auto mimeType = sectionResult[2];
                    return tuple!("priority", "mimeType", "lines")
                                 (priority, mimeType, parseMagicLines());
                }
            }
        }
        throw new Exception("Error parsing magic section");
    }
    
    void popFront() {
        
    }
    
    @property bool empty() {
        return _content.length <= 1;
    }
    
private:
    auto parseMagicLines() {
        MagicLine[] lines;
        while(!_content.empty && !_content.startsWith("[")) {
            lines ~= parseMagicLine();
        }
        return lines;
    }
    
    MagicLine parseMagicLine() {
        //Ugly code!
        
        auto strSplit = findSplit(_content, ">");
        if (strSplit[1].empty) {
            throw new Exception("Missing '>' character in magic line");
        }
        
        auto indent = strSplit[0].empty ? 0 : parse!uint(strSplit[0]);
        
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
                
                const(char)[] mask;
                uint wordSize;
                uint rangeLength;
                if (!valueStr.empty && valueStr.front == '&') {
                    valueStr.popFront();
                    if (valueStr.length >= valueLength) {
                        mask = valueStr[0..valueLength];
                        valueStr = valueStr[valueLength..$];
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
                if (valueStr.startsWith("\n")) {
                    valueStr.popFront();
                }
                _content = valueStr;
                return MagicLine(indent, startOffset, valueLength, value, mask, wordSize, rangeLength);
                //actually should check if the rest of string has symbols and ignore the whole line in this case.
            } else {
                throw new Exception("Failed to read value in magic line");
            }
        } else {
            throw new Exception("Failed to read value length in magic line");
        }
        
    }
    
    const(char)[] _content;
}

private auto magicRange(const(char)[] data) {
    return MagicRange(data);
}

@trusted auto magicFileReader(const(void)[] data)
{
    enum mimeMagic = "MIME-Magic\0\n";
    auto content = cast(const(char)[])data;
    if (!content.startsWith(mimeMagic)) {
        throw new Exception("Not mime magic file");
    }
    content = content[mimeMagic.length..$];
    return magicRange(content);
}

@trusted auto magicFileReader(string fileName) {
    return magicFileReader(std.file.read(fileName));
}

