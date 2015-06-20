module mime.database.mimecache;

private {
    import std.mmfile;
    
    import std.algorithm;
    
    import std.exception;
    import std.traits;
    import std.bitmanip;
    import std.system;
    import std.typecons;
    
    import std.stdio;
}

struct MimeCacheHeader
{
    ushort majorVersion;
    ushort minorVersion;
    uint aliasListOffset;
    uint parentListOffset;
    uint literalListOffset;
    uint reverseSuffixTreeOffset;
    uint globListOffset;
    uint magicListOffset;
    uint namespaceListOffset;
    uint iconsListOffset;
    uint genericIconsListOffset;
}

struct GlobEntry
{
    uint globOffset;
    uint mimeTypeOffset;
    uint weightAndFlags;
}

struct AliasEntry
{
    uint aliasOffset;
    uint mimeTypeOffset;
}

struct LiteralEntry
{
    uint literalOffset;
    uint mimeTypeOffset;
    uint weightAndFlags;
}

void readMimeCache(string fileName)
{
    static void swapByteOrder(T)(ref T t) {
        t = swapEndian(t);
    }
    
    static auto parseWeightAndFlags(uint value) {
        return tuple(value & 0xFF, (value & 0x100) != 0);
    }
    
    T readValue(T)(uint offset) {
        T value = *(cast(const(T)*)mmaped[offset..(offset+T.sizeof)].ptr);
        static if (isIntegral!T && endian == Endian.littleEndian) {
            swapByteOrder(value);
        }
        return value;
    }
    
    auto mmaped = new MmFile(fileName);
    
    auto readString(uint offset) {
        uint end = offset;
        while(mmaped[end]) {
            end++;
        }
        return cast(const(char)[])mmaped[offset..end];
    }
    
    auto readString2(uint offset, uint length) {
        return cast(const(char)[])mmaped[offset..offset+length];
    }
    
    enforce(mmaped.length > MimeCacheHeader.sizeof);
    auto header = readValue!MimeCacheHeader(0);
    static if (endian == Endian.littleEndian) {
        swapByteOrder(header.majorVersion);
        swapByteOrder(header.minorVersion);
        swapByteOrder(header.aliasListOffset);
        swapByteOrder(header.parentListOffset);
        swapByteOrder(header.literalListOffset);
        swapByteOrder(header.reverseSuffixTreeOffset);
        swapByteOrder(header.globListOffset);
        swapByteOrder(header.magicListOffset);
        swapByteOrder(header.namespaceListOffset);
        swapByteOrder(header.iconsListOffset);
        swapByteOrder(header.genericIconsListOffset);
    }
    
    writeln("Major version: ", header.majorVersion);
    writeln("Minor version: ", header.minorVersion);
    
    void printEntries(uint startOffset, uint count, string name) {
        for (uint i=0; i<count; ++i) {
            uint offset = startOffset + count.sizeof + i*uint.sizeof*3;
            uint entryOffset = readValue!uint(offset);
            uint mimeTypeOffset = readValue!uint(offset + uint.sizeof);
            auto weightAndFlags = parseWeightAndFlags(readValue!uint(offset + uint.sizeof*2));
            writefln("%s: %s. MimeType: %s. Weight: %s. Cs: %s", name, readString(entryOffset), readString(mimeTypeOffset), weightAndFlags[0], weightAndFlags[1]);
        }
    }
    
    void printIconEntries(uint startOffset, uint count, string name) {
        for (uint i=0; i<count; ++i) {
            uint offset = startOffset + count.sizeof + i*uint.sizeof*2;
            uint mimeTypeOffset = readValue!uint(offset);
            uint iconOffset = readValue!uint(offset + uint.sizeof);
            writefln("%s: %s. MimeType: %s", name, readString(iconOffset), readString(mimeTypeOffset));
        }
    }
    
    auto globCount = readValue!uint(header.globListOffset);
    writeln("Glob count: ", globCount);
    printEntries(header.globListOffset, globCount, "Glob");
    
    auto iconCount = readValue!uint(header.iconsListOffset);
    writeln("Icon count: ", iconCount);
    printIconEntries(header.iconsListOffset, iconCount, "Icon");
    
    auto genericIconCount = readValue!uint(header.genericIconsListOffset);
    writeln("Generic Icon count: ", iconCount);
    printIconEntries(header.iconsListOffset, iconCount, "GenericIcon");
    
    auto literalCount = readValue!uint(header.literalListOffset);
    writeln("Literal count: ", literalCount);
    printEntries(header.literalListOffset, literalCount, "Literal");
    
    auto aliasCount = readValue!uint(header.aliasListOffset);
    writeln("Alias count: ", aliasCount);
    for (uint i=0; i<aliasCount; ++i) {
        uint offset = header.aliasListOffset + aliasCount.sizeof + i*uint.sizeof*2;
        uint entryOffset = readValue!uint(offset);
        uint mimeTypeOffset = readValue!uint(offset + uint.sizeof);
        writefln("Alias: %s. MimeType: %s", readString(entryOffset), readString(mimeTypeOffset));
    }
    
    auto parentListCount = readValue!uint(header.parentListOffset);
    writeln("Parent list count: ", parentListCount);
    for (uint i=0; i<parentListCount; ++i) {
        uint offset = header.parentListOffset + parentListCount.sizeof + i*uint.sizeof*2;
        uint mimeTypeOffset = readValue!uint(offset);
        uint parentsOffset = readValue!uint(offset + uint.sizeof);
        
        uint parentCount = readValue!uint(parentsOffset);
        for (uint j=0; j<parentCount; ++j) {
            uint parentMimeTypeOffset = readValue!uint(parentsOffset + parentCount.sizeof + j*uint.sizeof);
            writefln("MimeType: %s. Parent: %s", readString(mimeTypeOffset), readString(parentMimeTypeOffset));
        }
    }
    
    auto rootCount = readValue!uint(header.reverseSuffixTreeOffset);
    writeln("Root count: ", rootCount);
    
    auto firstRootOffset = readValue!uint(header.reverseSuffixTreeOffset + rootCount.sizeof);
    writeln("First root offset: ", firstRootOffset);
    
    void lookupLeaf(uint offset, uint count, uint depth = 0) {
        for (uint i=0; i<count; ++i) {
            dchar character = cast(dchar)readValue!uint(offset);
            
            if (character) {
                uint childrenCount = readValue!uint(offset + uint.sizeof);
                uint firstChildOffset = readValue!uint(offset + uint.sizeof*2);
                writefln("depth: %s, char: %s, childrenCount: %s, firstChildOffset: %s", depth, character, childrenCount, firstChildOffset);
                
                lookupLeaf(firstChildOffset, childrenCount, depth+1);
            } else {
                uint mimeTypeOffset = readValue!uint(offset + uint.sizeof);
                uint weightAndFlags = readValue!uint(offset + uint.sizeof*2);
                writefln("depth: %s, mimeType: %s", depth, readString(mimeTypeOffset));
            }
            offset += uint.sizeof * 3;
        }
    }
    
    lookupLeaf(firstRootOffset, rootCount);
    
    auto matchCount = readValue!uint(header.magicListOffset);
    auto maxExtent = readValue!uint(header.magicListOffset + uint.sizeof);
    auto firstMatchOffset = readValue!uint(header.magicListOffset + uint.sizeof*2);
    writeln("Match count: ", matchCount);
    writeln("Max Extent: ", maxExtent);
    writeln("First match offset: ", firstMatchOffset);
    
    for (uint i=0; i<matchCount; ++i) {
        uint matchOffset = firstMatchOffset + i*uint.sizeof*4;
        uint priority = readValue!uint(matchOffset);
        uint mimeTypeOffset = readValue!uint(matchOffset + uint.sizeof);
        uint matchletCount = readValue!uint(matchOffset + uint.sizeof*2);
        uint firstMatchletOffset = readValue!uint(matchOffset + uint.sizeof*3);
        
        writefln("Priority: %s. MimeType: %s. Matchletcount: %s", priority, readString(mimeTypeOffset), matchletCount);
        
        for (uint j=0; j<matchletCount; ++j) {
            uint matchletOffset = firstMatchletOffset + j*uint.sizeof*8;
            uint rangeStart = readValue!uint(matchletOffset);
            uint rangeLength = readValue!uint(matchletOffset + uint.sizeof);
            uint wordSize = readValue!uint(matchletOffset + uint.sizeof*2);
            uint valueLength = readValue!uint(matchletOffset + uint.sizeof*3);
            uint value = readValue!uint(matchletOffset + uint.sizeof*4);
            uint mask = readValue!uint(matchletOffset + uint.sizeof*5);
            uint childrenCount = readValue!uint(matchletOffset + uint.sizeof*6);
            uint firstChildOffset = readValue!uint(matchletOffset + uint.sizeof*7);
            
            writefln("Range start: %s. Range length: %s. Word size: %s. Value length: %s.", rangeStart, rangeLength, wordSize, valueLength);
            if (wordSize == 1) {
                auto s = readString2(value, valueLength);
                writeln("Value: ", s);
            } else {
                
            }
        }
    }
}
