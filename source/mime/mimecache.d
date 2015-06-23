module mime.database.mimecache;

private {
    import std.mmfile;
    
    import std.algorithm;
    import std.bitmanip;
    import std.exception;
    import std.path;
    import std.range;
    import std.string;
    import std.system;
    import std.traits;
    import std.typecons;
    import std.uni;
    import std.utf;
    
    import std.stdio;
    
    import std.c.string;
}

private struct MimeCacheHeader
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

private @nogc @safe void swapByteOrder(T)(ref T t) nothrow pure  {
    t = swapEndian(t);
}

private {
    alias Tuple!(const(char)[], "aliasName", const(char)[], "mimeType") AliasEntry;
    alias Tuple!(const(char)[], "mimeType", uint, "parentsOffset") ParentEntry;
    alias Tuple!(ubyte, "weight", bool, "cs") WeightAndCs;
    alias Tuple!(const(char)[], "glob", const(char)[], "mimeType", ubyte, "weight", bool, "cs") GlobEntry;
    alias Tuple!(const(char)[], "literal", const(char)[], "mimeType", ubyte, "weight", bool, "cs") LiteralEntry;
    alias Tuple!(const(char)[], "mimeType", const(char)[], "iconName") IconEntry;
    alias Tuple!(const(char)[], "mimeType", uint, "weight", bool, "cs") MimeTypeEntry;
    alias Tuple!(uint, "priority", const(char)[], "mimeType", uint, "matchletCount", uint, "firstMatchletOffset") MatchEntry;
    alias Tuple!(uint, "rangeStart", uint, "rangeLength", 
                 uint, "wordSize", uint, "valueLength", 
                 uint, "value", uint, "mask", 
                 uint, "childrenCount", uint, "firstChildOffset") MatchletEntry;
    
}

private @nogc @safe auto parseWeightAndFlags(uint value) nothrow pure {
    return WeightAndCs(value & 0xFF, (value & 0x100) != 0);
}

class MimeCache
{
    this(string fileName) {
        mmaped = new MmFile(fileName);
        enforce(mmaped.length > MimeCacheHeader.sizeof, "mime cache file is invalid");
        
        header = readValue!MimeCacheHeader(0);
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
        
        enforce(header.majorVersion == 1 && header.minorVersion == 2, "Unsupported mime cache format version");
        
        enforce(mmaped.length >= header.aliasListOffset + uint.sizeof, "Invalid alias list offset");
        enforce(mmaped.length >= header.parentListOffset + uint.sizeof, "Invalid parent list offset");
        enforce(mmaped.length >= header.literalListOffset + uint.sizeof, "Invalid literal list offset");
        enforce(mmaped.length >= header.reverseSuffixTreeOffset + uint.sizeof * 2, "Invalid reverse suffix tree offset");
        enforce(mmaped.length >= header.globListOffset + uint.sizeof, "Invalid glob list offset");
        enforce(mmaped.length >= header.magicListOffset + uint.sizeof * 3, "Invalid magic list offset");
        enforce(mmaped.length >= header.namespaceListOffset + uint.sizeof, "Invalid namespace list offset");
    }
    
    auto aliases() {
        auto aliasCount = readValue!uint(header.aliasListOffset);
        enforce(mmaped.length >= header.aliasListOffset + aliasCount.sizeof + aliasCount * uint.sizeof * 2, "Failed to read alias list");
        return iota(aliasCount)
                .map!(i => header.aliasListOffset + aliasCount.sizeof + i*uint.sizeof*2)
                .map!(offset => AliasEntry(readString(readValue!uint(offset)), readString(readValue!uint(offset+uint.sizeof))))
                .assumeSorted!(function(a,b) { return a.aliasName < b.aliasName; });
    }
    
    const(char)[] realName(const(char)[] aliasName) {
        auto aliasEntry = aliases().equalRange(AliasEntry(aliasName, null));
        return aliasEntry.empty ? null : aliasEntry.front.mimeType;
    }
    
    auto parents(const(char)[] mimeType) {
        auto parentEntry = parentEntries().equalRange(ParentEntry(mimeType, 0));
        uint parentsOffset, parentCount;
        
        if (parentEntry.empty) {
            parentsOffset = 0;
            parentCount = 0;
        } else {
            parentsOffset = parentEntry.front.parentsOffset;
            parentCount = readValue!uint(parentsOffset);
        }
        enforce(mmaped.length >= parentsOffset + parentCount.sizeof + parentCount*uint.sizeof, "Failed to read parents");
        return iota(parentCount)
                .map!(i => parentsOffset + parentCount.sizeof + i*uint.sizeof)
                .map!(offset => readString(readValue!uint(offset)));
    }
    
    auto globs() {
        auto globCount = readValue!uint(header.globListOffset);
        enforce(mmaped.length >= header.globListOffset + globCount.sizeof + globCount*uint.sizeof*3, "Failed to read globs");
        return iota(globCount)
                .map!(i => header.globListOffset + globCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto glob = readString(readValue!uint(offset));
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof));
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2));
                    return GlobEntry(glob, mimeType, weightAndCs.weight, weightAndCs.cs);
                });
    }
    
    auto literals() {
        auto literalCount = readValue!uint(header.literalListOffset);
        enforce(mmaped.length >= header.literalListOffset + literalCount.sizeof + literalCount*uint.sizeof*3, "Failed to read literals");
        return iota(literalCount)
                .map!(i => header.literalListOffset + literalCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto literal = readString(readValue!uint(offset));
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof));
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2));
                    return LiteralEntry(literal, mimeType, weightAndCs.weight, weightAndCs.cs);
                }).assumeSorted!(function(a,b) { return sicmp(a.literal, b.literal) < 0; });
    }
    
    auto icons() {
        return commonIcons(header.iconsListOffset);
    }
    
    auto genericIcons() {
        return commonIcons(header.genericIconsListOffset);
    }
    
    const(char)[] findIcon(const(char)[] mimeType) {
        auto icon = icons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
    }
    
    const(char)[] findGenericIcon(const(char)[] mimeType) {
        auto icon = genericIcons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
    }
    
    const(char)[] findByFileName(const(char)[] name) {
        auto mimeType = findByLiteral(name);
        if (mimeType.empty) {
            mimeType = findBySuffx(name);
        }
        if (mimeType.empty) {
            mimeType = findByGlob(name);
        }
        return mimeType;
    }
    
    const(char)[] findByGlob(const(char)[] name) {
        const(char)[] mimeType;
        uint weight = 0;
        foreach(glob; globs) {
            bool match;
            if (glob.cs) {
                match = globMatch!(std.path.CaseSensitive.yes)(name, glob.glob);
            } else {
                match = globMatch!(std.path.CaseSensitive.no)(name, glob.glob);
            }
            if (match) {
                if (!mimeType.empty) {
                    if (glob.weight > weight) {
                        mimeType = glob.mimeType;
                        weight = glob.weight;
                    }
                } else {
                    mimeType = glob.mimeType;
                    weight = glob.weight;
                }
            }
        }
        return mimeType;
    }
    
    const(char)[] findByLiteral(const(char)[] name) {
        auto literal = literals().equalRange(LiteralEntry(name, null, 0, false));
        return literal.empty ? null : literal.front.mimeType;
    }
    
    const(char)[] findBySuffx(const(char)[] name) {
        auto rootCount = readValue!uint(header.reverseSuffixTreeOffset);
        auto firstRootOffset = readValue!uint(header.reverseSuffixTreeOffset + rootCount.sizeof);
        
        MimeTypeEntry bestMatch;
        
        //how to handle case-sensitive / case-insensitive variants?
        lookupLeaf(firstRootOffset, rootCount, name.retro, delegate(MimeTypeEntry entry) {
            if (bestMatch.mimeType.empty) {
                bestMatch = entry;
            } else if (entry.mimeType.length > bestMatch.mimeType.length) {
                bestMatch = entry;
            } else if (entry.mimeType != bestMatch.mimeType) {
                //what to do if weights are equal? Also spec says that magic data should be used if the same pattern is provided by two or more MIME types.
                if (entry.weight > bestMatch.weight) {
                    bestMatch = entry;
                }
            }
        });
        
        return bestMatch.mimeType;
    }
    
    
private:
    void lookupLeaf(Range)(uint offset, uint count, Range name, void delegate (MimeTypeEntry) sink) {
        
        for (uint i=0; i<count; ++i) {
            dchar character = cast(dchar)readValue!uint(offset);
            
            if (character) {
                if (!name.empty && character == name.front) {
                    uint childrenCount = readValue!uint(offset + uint.sizeof);
                    uint firstChildOffset = readValue!uint(offset + uint.sizeof*2);
                    
                    auto save = name.save;
                    save.popFront;
                    
                    lookupLeaf(firstChildOffset, childrenCount, save, sink);
                }
            } else {
                uint mimeTypeOffset = readValue!uint(offset + uint.sizeof);
                auto weightAndCs = readValue!uint(offset + uint.sizeof*2).parseWeightAndFlags;
                sink(MimeTypeEntry(readString(mimeTypeOffset), weightAndCs.weight, weightAndCs.cs));
            }
            offset += uint.sizeof * 3;
        }
    }
    
    auto parentEntries() {
        auto parentListCount = readValue!uint(header.parentListOffset);
        enforce(mmaped.length >= header.parentListOffset + parentListCount.sizeof + parentListCount*uint.sizeof*2, "Failed to read parent list");
        return iota(parentListCount)
                .map!(i => header.parentListOffset + parentListCount.sizeof + i*uint.sizeof*2)
                .map!(offset => ParentEntry(readString(readValue!uint(offset)), readValue!uint(offset+uint.sizeof)))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }

    auto commonIcons(uint iconsListOffset) {
        auto iconCount = readValue!uint(iconsListOffset);
        enforce(mmaped.length >= iconsListOffset + iconCount.sizeof + iconCount*uint.sizeof*2, "Failed to read icons");
        return iota(iconCount)
                .map!(i => iconsListOffset + iconCount.sizeof + i*uint.sizeof*2)
                .map!(offset => IconEntry(readString(readValue!uint(offset)), readString(readValue!uint(offset+uint.sizeof))))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }
    
    T readValue(T)(uint offset) {
        T value = *(cast(const(T)*)mmaped[offset..(offset+T.sizeof)].ptr);
        static if (isIntegral!T && endian == Endian.littleEndian) {
            swapByteOrder(value);
        }
        return value;
    }
    
    auto readString(uint offset) {
        auto cstr = cast(const(char*))mmaped[offset..mmaped.length].ptr;
        return fromStringz(cstr);
    }
    
    auto readString(uint offset, uint length) {
        return cast(const(char)[])mmaped[offset..offset+length];
    }
    
    MmFile mmaped;
    MimeCacheHeader header;
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
            writeln("Children count: ", childrenCount);
            for (uint k=0; k<childrenCount; ++k) {
                uint offset = firstChildOffset + k*uint.sizeof*3;
                uint character = readValue!uint(offset);
                writeln(character);
            }
        }
    }
}
