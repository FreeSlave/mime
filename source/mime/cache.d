/**
 * Class for reading mime.cache files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015
 */

module mime.cache;

import mime.common;

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

private @nogc @trusted void swapByteOrder(T)(ref T t) nothrow pure  {
    
    static if( __VERSION__ < 2067 ) { //swapEndian was not @nogc
        ubyte[] bytes = (cast(ubyte*)&t)[0..T.sizeof];
        for (size_t i=0; i<bytes.length/2; ++i) {
            ubyte tmp = bytes[i];
            bytes[i] = bytes[T.sizeof-1-i];
            bytes[T.sizeof-1-i] = tmp;
        }
    } else {
        t = swapEndian(t);
    }
}

///Alias entry in mime cache.
alias Tuple!(const(char)[], "aliasName", const(char)[], "mimeType") AliasEntry;

///Other glob than literal or suffix glob pattern.
alias Tuple!(const(char)[], "glob", const(char)[], "mimeType", ubyte, "weight", bool, "cs") GlobEntry;
///Literal glob
alias Tuple!(const(char)[], "literal", const(char)[], "mimeType", ubyte, "weight", bool, "cs") LiteralEntry;

///Icon or generic icon entry in mime cache.
alias Tuple!(const(char)[], "mimeType", const(char)[], "iconName") IconEntry;

///XML namespace entry in mime cache.
alias Tuple!(const(char)[], "namespaceUri", const(char)[], "localName", const(char)[], "mimeType") NamespaceEntry;

///Magic match entry in mime cache.
alias Tuple!(uint, "weight", const(char)[], "mimeType", uint, "matchletCount", uint, "firstMatchletOffset") MatchEntry;

///Magic matchlet entry in mime cache.
alias Tuple!(uint, "rangeStart", uint, "rangeLength", 
                uint, "wordSize", uint, "valueLength", 
                const(char)[], "value", const(char)[], "mask", 
                uint, "childrenCount", uint, "firstChildOffset") //what are these?
MatchletEntry;

private {
    alias Tuple!(const(char)[], "mimeType", uint, "parentsOffset") ParentEntry;
    alias Tuple!(ubyte, "weight", bool, "cs") WeightAndCs;
    alias Tuple!(const(char)[], "mimeType", uint, "weight", bool, "cs", const(char)[], "suffix") MimeTypeEntry;
}

///MIME type alternative.
alias Tuple!(const(char)[], "mimeType", uint, "weight") MimeTypeAlternative;

private @nogc @safe auto parseWeightAndFlags(uint value) nothrow pure {
    return WeightAndCs(value & 0xFF, (value & 0x100) != 0);
}

/**
 * Class for reading mime.cache files. Mime cache is mainly optimized for MIME type detection by file name.
 * This class is somewhat low level and tricky to use in some cases. 
 * Also it knows nothing about MimeType struct.
 * Note: 
 *  This class does not try to provide more information than the underlying mime.cache file has.
 *  It does not return icon fallbacks for MIME types.
 *  It does not parse XML files to get the actual MIME type from namespace.
 */
final class MimeCache
{
    /**
     * Read mime cache from given file (usually mime.cache from one of mime paths)
     * Note: 
     *  File will be mapped into memory with MmFile.
     * Warning:
     *  Strings returned from MimeCache can't be considered permanent
     * and must be copied with $(B dup) or $(B idup) if their lifetime is longer than this object's one.
     * Throws: 
     *  FileException if could not map file into memory.
     *  Exception if provided file is not valid mime cache or unsupported version.
     */
    @trusted this(string fileName) {
        mmaped = new MmFile(fileName);
        _data = mmaped[];
        _fileName = fileName;
        construct();
    }
    
    /**
     * Read mime cache from given data.
     * Throws:
     *  Exception if provided file is not valid mime cache or unsupported version.
     */
    @trusted this(immutable(void)[] data, string fileName = null) {
        _data = data;
        _fileName = fileName;
        construct();
    }
    
    /**
     * File name MimeCache was loaded from.
     */
    @nogc @safe string fileName() nothrow const {
        return _fileName;
    }
    
    private @trusted void construct() {
        enforce(_data.length > MimeCacheHeader.sizeof, "mime cache file is invalid");
        
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
        
        enforce(_data.length >= header.aliasListOffset + uint.sizeof, "Invalid alias list offset");
        enforce(_data.length >= header.parentListOffset + uint.sizeof, "Invalid parent list offset");
        enforce(_data.length >= header.literalListOffset + uint.sizeof, "Invalid literal list offset");
        enforce(_data.length >= header.reverseSuffixTreeOffset + uint.sizeof * 2, "Invalid reverse suffix tree offset");
        enforce(_data.length >= header.globListOffset + uint.sizeof, "Invalid glob list offset");
        enforce(_data.length >= header.magicListOffset + uint.sizeof * 3, "Invalid magic list offset");
        enforce(_data.length >= header.namespaceListOffset + uint.sizeof, "Invalid namespace list offset");
    }
    
    /**
     * MIME type aliases.
     * Returns: SortedRange of AliasEntry tuples sorted by aliasName.
     */
    @trusted auto aliases() const {
        auto aliasCount = readValue!uint(header.aliasListOffset);
        enforce(_data.length >= header.aliasListOffset + aliasCount.sizeof + aliasCount * uint.sizeof * 2, "Failed to read alias list");
        return iota(aliasCount)
                .map!(i => header.aliasListOffset + aliasCount.sizeof + i*uint.sizeof*2)
                .map!(offset => AliasEntry(readString(readValue!uint(offset)), readString(readValue!uint(offset+uint.sizeof))))
                .assumeSorted!(function(a,b) { return a.aliasName < b.aliasName; });
    }
    
    /**
     * Get the real MIME type name.
     * Returns: resolved name if mimeType is alias or mimeType itself if no aliases found.
     */
    @trusted const(char)[] realName(const(char)[] mimeType) const {
        const(char)[] name = resolveAlias(mimeType);
        if (name.length) {
            return name;
        } else {
            return mimeType;
        }
    }
    
    /**
     * Resolve MIME type name by aliasName.
     * Returns: real MIME type name or null if could not found any.
     */
    @trusted const(char)[] resolveAlias(const(char)[] aliasName) const {
        auto aliasEntry = aliases().equalRange(AliasEntry(aliasName, null));
        return aliasEntry.empty ? null : aliasEntry.front.mimeType;
    }
    
    /**
     * Get parents of given mimeType.
     * Note: only first level parents are returned.
     * Returns: Range of parents for given mimeType.
     */
    @trusted auto parents(const(char)[] mimeType) const {
        auto parentEntry = parentEntries().equalRange(ParentEntry(mimeType, 0));
        uint parentsOffset, parentCount;
        
        if (parentEntry.empty) {
            parentsOffset = 0;
            parentCount = 0;
        } else {
            parentsOffset = parentEntry.front.parentsOffset;
            parentCount = readValue!uint(parentsOffset);
        }
        enforce(_data.length >= parentsOffset + parentCount.sizeof + parentCount*uint.sizeof, "Failed to read parents");
        return iota(parentCount)
                .map!(i => parentsOffset + parentCount.sizeof + i*uint.sizeof)
                .map!(offset => readString(readValue!uint(offset)));
    }
    
    /**
     * Glob patterns that are not literal nor suffixes.
     * Returns: Range of GlobEntry tuples.
     */
    @trusted auto globs() const {
        auto globCount = readValue!uint(header.globListOffset);
        enforce(_data.length >= header.globListOffset + globCount.sizeof + globCount*uint.sizeof*3, "Failed to read globs");
        return iota(globCount)
                .map!(i => header.globListOffset + globCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto glob = readString(readValue!uint(offset));
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof));
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2));
                    return GlobEntry(glob, mimeType, weightAndCs.weight, weightAndCs.cs);
                });
    }
    
    /**
     * Literal patterns.
     * Returns: SortedRange of LiteralEntry tuples sorted by literal.
     */
    @trusted auto literals() const {
        auto literalCount = readValue!uint(header.literalListOffset);
        enforce(_data.length >= header.literalListOffset + literalCount.sizeof + literalCount*uint.sizeof*3, "Failed to read literals");
        return iota(literalCount)
                .map!(i => header.literalListOffset + literalCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto literal = readString(readValue!uint(offset));
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof));
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2));
                    return LiteralEntry(literal, mimeType, weightAndCs.weight, weightAndCs.cs);
                }).assumeSorted!(function(a,b) { return a.literal < b.literal; });
    }
    
    /**
     * Icons for MIME types.
     * Returns: SortedRange of IconEntry tuples sorted by mimeType.
     */
    @trusted auto icons() const {
        return commonIcons(header.iconsListOffset);
    }
    
    /**
     * Generic icons for MIME types.
     * Returns: SortedRange of IconEntry tuples sorted by mimeType.
     */
    @trusted auto genericIcons() const {
        return commonIcons(header.genericIconsListOffset);
    }
    
    /**
     * XML namespaces for MIME types.
     * Returns: SortedRange of NamespaceEntry tuples sorted by namespaceUri.
     */
    @trusted auto namespaces() const {
        auto namespaceCount = readValue!uint(header.namespaceListOffset);
        enforce(_data.length >= header.namespaceListOffset + namespaceCount.sizeof + namespaceCount*uint.sizeof*3, "Failed to read namespaces");
        return iota(namespaceCount)
                .map!(i => header.namespaceListOffset + namespaceCount.sizeof + i*uint.sizeof*3)
                .map!(offset => NamespaceEntry(readString(readValue!uint(offset)), 
                                               readString(readValue!uint(offset+uint.sizeof)), 
                                               readString(readValue!uint(offset+uint.sizeof*2))))
                .assumeSorted!(function(a,b) { return a.namespaceUri < b.namespaceUri; });
    }
    
    @trusted auto magicMatches() const {
        auto matchCount = readValue!uint(header.magicListOffset);
        auto maxExtent = readValue!uint(header.magicListOffset + uint.sizeof); //what is it? Spec does not say anything
        auto firstMatchOffset = readValue!uint(header.magicListOffset + uint.sizeof*2);
        
        enforce(_data.length >= firstMatchOffset + matchCount*uint.sizeof*4);
        
        return iota(matchCount)
                .map!(i => firstMatchOffset + i*uint.sizeof*4)
                .map!(offset => MatchEntry(readValue!uint(offset), 
                                           readString(readValue!uint(offset+uint.sizeof)), 
                                           readValue!uint(offset+uint.sizeof*2), 
                                           readValue!uint(offset+uint.sizeof*3)));
    }
    
    @trusted auto magicMatchlets(uint matchletCount, uint firstMatchletOffset) const {
        return iota(matchletCount)
                .map!(i => firstMatchletOffset + i*uint.sizeof*8)
                .map!(delegate(offset) {
                    uint rangeStart = readValue!uint(offset);
                    uint rangeLength = readValue!uint(offset+uint.sizeof);
                    uint wordSize = readValue!uint(offset+uint.sizeof*2);
                    uint valueLength = readValue!uint(offset+uint.sizeof*3);
                    
                    uint valueOffset = readValue!uint(offset+uint.sizeof*4);
                    const(char)[] value = readString(valueOffset, valueLength);
                    uint maskOffset = readValue!uint(offset+uint.sizeof*5);
                    const(char)[] mask = maskOffset ? readString(maskOffset, valueLength) : null;
                    uint childrenCount = readValue!uint(offset+uint.sizeof*6);
                    uint firstChildOffset = readValue!uint(offset+uint.sizeof*7);
                    return MatchletEntry(rangeStart, rangeLength, wordSize, valueLength, value, mask, childrenCount, firstChildOffset);
                });
    }
    
    /**
     * Returns: Icon name for given mimeType.
     */
    @trusted const(char)[] findIcon(const(char)[] mimeType) const {
        auto icon = icons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
    }
    
    /**
     * Returns: Generic icon name for given mimeType.
     */
    @trusted const(char)[] findGenericIcon(const(char)[] mimeType) const {
        auto icon = genericIcons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
    }
    
    /**
     * Find all MIME type alternatives for file name.
     * Params:
     *  name = file name.
     * Returns: Range of MimeTypeAlternative tuples matching with file name.
     */
    @trusted auto findAllByFileName(const(char)[] name) const {
        return chain(findAllByLiteral(name), findAllBySuffx(name), findAllByGlob(name));
    }
    
    /**
     * Find the most preferable (those with the highest priority) MIME types by file name.
     * Params:
     *  name = file name.
     *  pweight = if not null, the highest found priority is returned to pointed variable.
     * Returns: 
     *  Array of MIME type names matching with file name or empty array if no matches found.
     */
    @trusted const(char)[][] findByFileName(const(char)[] name, uint* pweight = null) const {
        const(char)[][] conflicts;
        const(char)[] mimeType;
        uint weight = 0;
        
        foreach(alternative; findAllByFileName(name)) {
            if (mimeType.empty || alternative.weight > weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                conflicts = null;
            } else if (alternative.weight == weight) {
                conflicts ~= alternative.mimeType;
            }
        }
        
        if (pweight) {
            *pweight = weight;
        }
        
        return mimeType ~ conflicts;
    }
    
    /**
     * Find the most preferable MIME type by file name. If there're more than one MIME type with the same priority the first found will be used.
     * Params:
     *  name = file name.
     *  pweight = if not null, the priority of the most preferable MIME type is returned to pointed variable.
     * Returns: 
     *  The most preferable MIME type for file name or empty string if no match found.
     */
    @trusted const(char)[] findOneByFileName(const(char)[] name, uint* pweight = null) const {
        const(char)[] mimeType;
        uint weight = 0;
        
        foreach(alternative; findAllByFileName(name)) {
            if (mimeType.empty || alternative.weight > weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
            }
        }
        if (pweight) {
            *pweight = weight;
        }
        return mimeType;
    }
    
    private @trusted bool checkMagic(const(MatchletEntry) magicMatchlet, const(char)[] content) const  {
        
        bool check = false;
        if (magicMatchlet.mask.length == 0 && magicMatchlet.rangeStart + magicMatchlet.value.length <= content.length) {
            if (magicMatchlet.wordSize == 1) {
                check = content[magicMatchlet.rangeStart..$].startsWith(magicMatchlet.value);
            } 
            //not sure how to deal with for now
            /+else if (magicMatchlet.wordSize && (magicMatchlet.wordSize % 2 == 0) && (magicMatchlet.valueLength % magicMatchlet.wordSize == 0)) {
                static if (endian == Endian.littleEndian) {
                    check = content[magicMatchlet.rangeStart..$].byChar.startsWith(magicMatchlet.value.byChar.retro.chunks(magicMatchlet.wordSize).joiner);
                } else {
                    check = content[magicMatchlet.rangeStart..$].startsWith(magicMatchlet.value);
                }
            }+/
        }
        if(check) {
            if (magicMatchlet.childrenCount) {
                foreach(childMatchlet; magicMatchlets(magicMatchlet.childrenCount, magicMatchlet.firstChildOffset)) {
                    check = check && checkMagic(childMatchlet, content);
                    if (!check) {
                        return false;
                    }
                }
            }
        }
        return check;
    }
    
    /**
     * Find all MIME type alternatives for data.
     * Params:
     *  data = data to check against magic.
     * Returns: Range of MimeTypeAlternative tuples matching with given data.
     */
    @trusted auto findAllByData(const(void)[] data) const {
        auto content = cast(const(char)[])data;
        
        alias Tuple!(const(char)[], "mimeType", uint, "weight", MatchletEntry, "matchlet") MM;
        
        return magicMatches()
            .map!(magicMatch => magicMatchlets(magicMatch.matchletCount, magicMatch.firstMatchletOffset)
                .map!(magicMatchlet => MM(magicMatch.mimeType, magicMatch.weight, magicMatchlet)) )
            .joiner()
            .filter!(magic => checkMagic(magic.matchlet, content))
            .map!(magic => MimeTypeAlternative(magic.mimeType, magic.weight));
    }
    
    /**
     * Find the most preferable (those with the highest priority) MIME types by data.
     * Params:
     *  data = data to check against magic.
     *  pweight = if not null, the highest found priority is returned to pointed variable.
     * Returns: 
     *  Array of MIME type names matching with given data or empty array if no matches found.
     */
    @trusted const(char)[][] findByData(const(void)[] data, uint* pweight = null) const {
        const(char)[][] conflicts;
        
        const(char)[] mimeType;
        uint weight = 0;
        
        foreach(alternative; findAllByData(data)) {
            if (mimeType.empty || alternative.weight > weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                conflicts = null;
            } else if (alternative.weight == weight) {
                conflicts ~= alternative.mimeType;
            }
        }
        
        if (pweight) {
            *pweight = weight;
        }
        
        return mimeType ~ conflicts;
    }
    
    /**
     * Find the most preferable MIME type by data. If there're more than one MIME type with the same priority the first found will be used.
     * Params:
     *  data = data to check against magic.
     *  pweight = if not null, the priority of the most preferable MIME type is returned to pointed variable.
     * Returns: 
     *  The most preferable MIME type for data or empty string if no match found.
     */
    @trusted const(char)[] findOneByData(const(void)[] data, uint* pweight = null) const {
        const(char)[] mimeType;
        uint weight = 0;
        
        foreach(alternative; findAllByData(data)) {
            if (mimeType.empty || alternative.weight > weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
            }
        }
        if (pweight) {
            *pweight = weight;
        }
        return mimeType;
    }
    
    /**
     * Get MIME type for file using both name and data. 
     * At first this function examines MIME type only by fileName without actual file reading.
     * If MIME type was not found or conflicts are met, it reads file and use magic rules to resolve MIME type.
     * Params:
     *  fileName = name of examined file.
     *  data = lazy expression that will be used to retrieve data from file in case of conflicts.
     */
    @trusted const(char)[] findOneByFile(const(char)[] fileName, lazy const(void)[] data) const {
        const(char)[][] alternatives = findByFileName(fileName);
        const(char)[] mimeType = null;
        if (alternatives.length) {
            mimeType = alternatives.front;
        }
        
        if (alternatives.length != 1 && data) {
            const(void)[] readData = data();
            if (readData.length) {
                const(char)[] dataMimeType = findOneByData(readData);
                if (dataMimeType.length) {
                    mimeType = dataMimeType;
                }
            }
        }
        return mimeType;
    }
    
private:
    @trusted auto findAllByGlob(const(char)[] name) const {
        name = name.baseName;
        return globs().filter!(delegate(GlobEntry glob) { 
            if (glob.cs) {
                return globMatch!(std.path.CaseSensitive.yes)(name, glob.glob);
            } else {
                return globMatch!(std.path.CaseSensitive.no)(name, glob.glob);
            }
        }).map!(glob => MimeTypeAlternative(glob.mimeType, glob.weight));
    }
    
    @trusted auto findAllByLiteralHelper(const(char)[] name) const {
        name = name.baseName;
        //Case-sensitive match is always preferred
        auto csLiteral = literals().equalRange(LiteralEntry(name, null, 0, false));
        if (csLiteral.empty) {
            //Try case-insensitive match. toLower should work for this since all case-insensitive literals in mime.cache are stored in lower form.
            return literals().equalRange(LiteralEntry(name.toLower, null, 0, false));
        } else {
            return csLiteral;
        }
    }
    
    @trusted auto findAllByLiteral(const(char)[] name) const {
        return findAllByLiteralHelper(name).map!(literal => MimeTypeAlternative(literal.mimeType, literal.weight));
    }
    
    @trusted auto findAllBySuffx(const(char)[] name) const {
        auto rootCount = readValue!uint(header.reverseSuffixTreeOffset);
        auto firstRootOffset = readValue!uint(header.reverseSuffixTreeOffset + rootCount.sizeof);
        
        MimeTypeEntry[] matches;
        void addMatch(MimeTypeEntry entry) {
            if (!matches.empty && matches.back.suffix.length < entry.suffix.length) {
                matches[$-1] = entry;
            } else {
                matches ~= entry;
            }
        }
        lookupLeaf(firstRootOffset, rootCount, name, name, &addMatch);
        
        return matches.map!(match => MimeTypeAlternative(match.mimeType, match.weight));
    }
    
    @trusted void lookupLeaf(const uint startOffset, const uint count, const(char[]) originalName, const(char[]) name, void delegate (MimeTypeEntry) sink, const(char[]) suffix = null, const bool wasCaseMismatch = false) const {
        
        for (uint i=0; i<count; ++i) {
            const size_t offset = startOffset + i * uint.sizeof * 3;
            auto character = readValue!dchar(offset);
            
            if (character) {
                if (name.length) {
                    dchar back = name.back;
                    if (character.toLower == back.toLower) {
                        uint childrenCount = readValue!uint(offset + uint.sizeof);
                        uint firstChildOffset = readValue!uint(offset + uint.sizeof*2);
                        const(char)[] currentName = name;
                        currentName.popBack();
                        bool caseMismatch = character != back;
                        lookupLeaf(firstChildOffset, childrenCount, originalName, currentName, sink, originalName[currentName.length..$], caseMismatch);
                    }
                }
            } else {
                uint mimeTypeOffset = readValue!uint(offset + uint.sizeof);
                auto weightAndCs = readValue!uint(offset + uint.sizeof*2).parseWeightAndFlags;
                
                auto mimeTypeEntry = MimeTypeEntry(readString(mimeTypeOffset), weightAndCs.weight, weightAndCs.cs, suffix);
                
                //if case sensitive make sure that file name ends with suffix
                if (weightAndCs.cs) {
                    if (!wasCaseMismatch) {
                        sink(mimeTypeEntry);
                    }
                } else {
                    sink(mimeTypeEntry);
                }
            }
        }
    }
    
    auto parentEntries() const {
        auto parentListCount = readValue!uint(header.parentListOffset);
        enforce(_data.length >= header.parentListOffset + parentListCount.sizeof + parentListCount*uint.sizeof*2, "Failed to read parent list");
        return iota(parentListCount)
                .map!(i => header.parentListOffset + parentListCount.sizeof + i*uint.sizeof*2)
                .map!(offset => ParentEntry(readString(readValue!uint(offset)), readValue!uint(offset+uint.sizeof)))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }

    @trusted auto commonIcons(uint iconsListOffset) const {
        auto iconCount = readValue!uint(iconsListOffset);
        enforce(_data.length >= iconsListOffset + iconCount.sizeof + iconCount*uint.sizeof*2, "Failed to read icons");
        return iota(iconCount)
                .map!(i => iconsListOffset + iconCount.sizeof + i*uint.sizeof*2)
                .map!(offset => IconEntry(readString(readValue!uint(offset)), readString(readValue!uint(offset+uint.sizeof))))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }
    
    @nogc @trusted T readValue(T)(size_t offset) const nothrow {
        T value = *(cast(const(T)*)_data[offset..(offset+T.sizeof)].ptr);
        static if (endian == Endian.littleEndian && (isIntegral!T || isSomeChar!T) ) {
            swapByteOrder(value);
        }
        return value;
    }
    
    @nogc @trusted auto readString(size_t offset) const nothrow {
        auto cstr = cast(const(char*))_data[offset.._data.length].ptr;
        return fromCString(cstr);
    }
    
    @nogc @trusted auto readString(size_t offset, uint length) const nothrow {
        return cast(const(char)[])_data[offset..offset+length];
    }
    
    MmFile mmaped;
    const(void)[] _data;
    MimeCacheHeader header;
    string _fileName;
}
