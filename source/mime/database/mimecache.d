module mime.database.mimecache;

private {
    import std.mmfile;
    
    import std.algorithm;
    
    import std.exception;
    import std.traits;
    import std.bitmanip;
    import std.system;
    
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
            uint weightAndFlags = readValue!uint(offset + uint.sizeof*2);
            writefln("%s: %s. MimeType: %s", name, readString(entryOffset), readString(mimeTypeOffset));
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
    printEntries(header.aliasListOffset, aliasCount, "Alias");
    
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
}
