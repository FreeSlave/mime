module mime.database.magic;

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

private struct MagicLines
{
    this(const(char)[] content) {
        _current = content;
    }
    
    @property auto front() {
        const(char)[] copy = _current;
        return parseLine(copy);
    }
    
    void popFront() {
        parseLine(_current);
    }
    
    bool empty() const {
        return _current.empty || _current.startsWith("[");
    }
    
    MagicLines save() const {
        return MagicLines(_current);
    }
    
private:
    auto current() {
        return _current;
    }
    
    auto parseLine(ref const(char)[] current) {
        //Ugly code!
        
        auto strSplit = findSplit(current, ">");
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
                //actually should check if the rest of string has symbols and ignore the whole line in this case.
                if (valueStr.startsWith("\n")) {
                    valueStr.popFront();
                }
                current = valueStr;
                return MagicLine(indent, startOffset, valueLength, value, mask, wordSize, rangeLength);
            } else {
                throw new Exception("Failed to read value in magic line");
            }
        } else {
            throw new Exception("Failed to read value length in magic line");
        }
    }
    
    const(char)[] _current;
}

alias Tuple!(uint, "priority", const(char)[], "mimeType", MagicLines, "lines") MagicSection;

private struct MagicRange
{
    this(const(char)[] content) {
        _current = content;
    }
    
    //Should use caching?
    @property auto front() {
        auto current = _current;
        if (current.startsWith("[")) {
            current = current[1..$];
            
            auto result = findSplit(current[0..$], "]\n");
            if (!result[1].empty) {
                current = result[2];
                
                auto sectionResult = findSplit(result[0], ":");
                if (!sectionResult[1].empty) {
                    uint priority = parse!uint(sectionResult[0]);
                    auto mimeType = sectionResult[2];
                    return MagicSection(priority, mimeType, MagicLines(current));
                }
            }
        }
        throw new Exception("Error parsing magic section");
    }
    
    void popFront() {
        //Ugly! Need to call front again and foreach over the subrange. Caching would solve the first problem.
        auto result = front();
        while(!result.lines.empty) {
            result.lines.popFront();
        }
        _current = result.lines.current();
    }
    
    @property bool empty() const {
        return _current.empty;
    }
    
    MagicRange save() const {
        return MagicRange(_current);
    }
    
private:
    const(char)[] _current;
}

@trusted auto magicFileReader(const(void)[] data)
{
    enum mimeMagic = "MIME-Magic\0\n";
    auto content = cast(const(char)[])data;
    if (!content.startsWith(mimeMagic)) {
        throw new Exception("Not mime magic file");
    }
    return MagicRange(content[mimeMagic.length..$]);
}

