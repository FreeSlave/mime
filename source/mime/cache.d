/**
 * Class for reading mime.cache files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.cache;

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
    
    static if( __VERSION__ < 2066 ) enum nogc = 1;
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
                uint, "childrenCount", uint, "firstChildOffset")
MatchletEntry;

private {
    alias Tuple!(const(char)[], "mimeType", uint, "parentsOffset") ParentEntry;
    alias Tuple!(ubyte, "weight", bool, "cs") WeightAndCs;
}

/// MIME type alternative found by file name.
alias Tuple!(const(char)[], "mimeType", uint, "weight", bool, "cs", const(char)[], "pattern") MimeTypeAlternativeByName;

/// MIME type alternative found by data.
alias Tuple!(const(char)[], "mimeType", uint, "weight") MimeTypeAlternative;

private @nogc @safe auto parseWeightAndFlags(uint value) nothrow pure {
    return WeightAndCs(value & 0xFF, (value & 0x100) != 0);
}

/**
 * Error occured while parsing mime cache.
 */
class MimeCacheException : Exception
{
    this(string msg, string context = null, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
        _context = context;
    }
    
    /**
     * Context where error occured. Usually it's the name of value that could not be read or is invalid.
     */
    @nogc @safe string context() const nothrow {
        return _context;
    }
private:
    string _context;
}

/**
 * Class for reading mime.cache files. Mime cache is mainly optimized for MIME type detection by file name.
 * This class is somewhat low level and tricky to use directly. 
 * Also it knows nothing about mime.type.MimeType.
 * Note: 
 *  This class does not try to provide more information than the underlying mime.cache file has.
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
     *  MimeCacheException if provided file is not valid mime cache or unsupported version.
     */
    @trusted this(string fileName) {
        _mmapped = new MmFile(fileName);
        this(_mmapped[], fileName, 0);
    }
    
    /**
     * Read mime cache from given data.
     * Throws:
     *  MimeCacheException if provided file is not valid mime cache or unsupported version.
     */
    @safe this(immutable(void)[] data, string fileName = null) {
        this(data, fileName, 0);
    }
    
    /**
     * File name MimeCache was loaded from.
     */
    @nogc @safe string fileName() nothrow const {
        return _fileName;
    }
    
    private @trusted this(const(void)[] data, string fileName, int /* To avoid ambiguity */) {
        _data = data;
        _fileName = fileName;
        
        _header.majorVersion = readValue!ushort(0, "major version");
        if (_header.majorVersion != 1) {
            throw new MimeCacheException("Unsupported mime cache format version or the file is not mime cache", "major version");
        }
        
        _header.minorVersion = readValue!ushort(2, "minor version");
        if (_header.minorVersion != 2) {
            throw new MimeCacheException("Unsupported mime cache format version or the file is not mime cache", "minor version");
        }
        
        _header.aliasListOffset = readValue!uint(4, "alias list offset");
        _header.parentListOffset = readValue!uint(8, "parent list offset");
        _header.literalListOffset = readValue!uint(12, "literal list offset");
        _header.reverseSuffixTreeOffset = readValue!uint(16, "reverse suffix tree offset");
        _header.globListOffset = readValue!uint(20, "glob list offset");
        _header.magicListOffset = readValue!uint(24, "magic list offset");
        _header.namespaceListOffset = readValue!uint(28, "namespace list offset");
        _header.iconsListOffset = readValue!uint(32, "icon list offset");
        _header.genericIconsListOffset = readValue!uint(36, "generic list offset");
    }
    
    /**
     * MIME type aliases.
     * Returns: SortedRange of AliasEntry tuples sorted by aliasName.
     */
    @trusted auto aliases() const {
        auto aliasCount = readValue!uint(_header.aliasListOffset, "alist count");
        return iota(aliasCount)
                .map!(i => _header.aliasListOffset + aliasCount.sizeof + i*uint.sizeof*2)
                .map!(offset => AliasEntry(
                    readString(readValue!uint(offset, "alias offset"), "alias name"), 
                    readString(readValue!uint(offset+uint.sizeof, "mime type offset"), "mime type name")
                ))
                .assumeSorted!(function(a,b) { return a.aliasName < b.aliasName; });
    }
    
    /**
     * Resolve MIME type name by aliasName.
     * Returns: resolved MIME type name or null if could not found any mime type for this aliasName.
     */
    @trusted const(char)[] resolveAlias(const(char)[] aliasName) const {
        auto aliasEntry = aliases().equalRange(AliasEntry(aliasName, null));
        return aliasEntry.empty ? null : aliasEntry.front.mimeType;
    }
    
    /**
     * Get direct parents of given mimeType.
     * Returns: Range of first level parents for given mimeType.
     */
    @trusted auto parents(const(char)[] mimeType) const {
        auto parentEntry = parentEntries().equalRange(ParentEntry(mimeType, 0));
        uint parentsOffset, parentCount;
        
        if (parentEntry.empty) {
            parentsOffset = 0;
            parentCount = 0;
        } else {
            parentsOffset = parentEntry.front.parentsOffset;
            parentCount = readValue!uint(parentsOffset, "parent count");
        }
        return iota(parentCount)
                .map!(i => parentsOffset + parentCount.sizeof + i*uint.sizeof)
                .map!(offset => readString(readValue!uint(offset, "mime type offset"), "mime type name"));
    }
    
    /**
     * Glob patterns that are not literal nor suffixes.
     * Returns: Range of GlobEntry tuples.
     */
    @trusted auto globs() const {
        auto globCount = readValue!uint(_header.globListOffset, "glob count");
        return iota(globCount)
                .map!(i => _header.globListOffset + globCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto glob = readString(readValue!uint(offset, "glob offset"), "glob pattern");
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof, "mime type offset"), "mime type name");
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2, "weight and flags"));
                    return GlobEntry(glob, mimeType, weightAndCs.weight, weightAndCs.cs);
                });
    }
    
    /**
     * Literal patterns.
     * Returns: SortedRange of LiteralEntry tuples sorted by literal.
     */
    @trusted auto literals() const {
        auto literalCount = readValue!uint(_header.literalListOffset, "literal count");
        return iota(literalCount)
                .map!(i => _header.literalListOffset + literalCount.sizeof + i*uint.sizeof*3)
                .map!(delegate(offset) { 
                    auto literal = readString(readValue!uint(offset, "literal offset"), "literal");
                    auto mimeType = readString(readValue!uint(offset+uint.sizeof, "mime type offset"), "mime type name");
                    auto weightAndCs = parseWeightAndFlags(readValue!uint(offset+uint.sizeof*2, "weight and flags"));
                    return LiteralEntry(literal, mimeType, weightAndCs.weight, weightAndCs.cs);
                }).assumeSorted!(function(a,b) { return a.literal < b.literal; });
    }
    
    /**
     * Icons for MIME types.
     * Returns: SortedRange of IconEntry tuples sorted by mimeType.
     */
    @trusted auto icons() const {
        return commonIcons(_header.iconsListOffset);
    }
    
    /**
     * Generic icons for MIME types.
     * Returns: SortedRange of IconEntry tuples sorted by mimeType.
     */
    @trusted auto genericIcons() const {
        return commonIcons(_header.genericIconsListOffset);
    }
    
    /**
     * XML namespaces for MIME types.
     * Returns: SortedRange of NamespaceEntry tuples sorted by namespaceUri.
     */
    @trusted auto namespaces() const {
        auto namespaceCount = readValue!uint(_header.namespaceListOffset, "namespace count");
        return iota(namespaceCount)
                .map!(i => _header.namespaceListOffset + namespaceCount.sizeof + i*uint.sizeof*3)
                .map!(offset => NamespaceEntry(readString(readValue!uint(offset, "namespace uri offset"), "namespace uri"), 
                                               readString(readValue!uint(offset+uint.sizeof, "local name offset"), "local name"), 
                                               readString(readValue!uint(offset+uint.sizeof*2, "mime type offset"), "mime type name")))
                .assumeSorted!(function(a,b) { return a.namespaceUri < b.namespaceUri; });
    }
    
    @trusted const(char)[] findMimeTypeByNamespaceUri(const(char)[] namespaceUri) const
    {
        auto namespaceEntry = namespaces().equalRange(NamespaceEntry(namespaceUri, null, null));
        return namespaceEntry.empty ? null : namespaceEntry.front.mimeType;
    }
    
    /**
     * Find icon name for mime type.
     * Returns: Icon name for given mimeType or null string if not found.
     */
    @trusted const(char)[] findIcon(const(char)[] mimeType) const {
        auto icon = icons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
    }
    
    /**
     * Find generic icon name for mime type.
     * Returns: Generic icon name for given mimeType or null string if not found.
     */
    @trusted const(char)[] findGenericIcon(const(char)[] mimeType) const {
        auto icon = genericIcons().equalRange(IconEntry(mimeType, null));
        return icon.empty ? null : icon.front.iconName;
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
     * Find all MIME type alternatives for data matching it against magic rules.
     * Params:
     *  data = data to check against magic.
     * Returns: Range of MimeTypeAlternative tuples matching given data sorted by weight descending.
     */
    @trusted auto findMimeTypesByData(const(void)[] data) const
    {
        return magicMatches()
            .filter!(match => checkMatchlets(data, match.matchletCount, match.firstMatchletOffset))
            .map!(match => MimeTypeAlternative(match.mimeType, match.weight));
    }
    
    private bool checkMatchlets(const(void)[] data, uint matchletCount, uint firstMatchletOffset) const
    {
        auto content = cast(const(char)[])data;
        foreach(matchlet; magicMatchlets(matchletCount, firstMatchletOffset))
        {
            if (checkMagic(matchlet, content)) {
                if (matchlet.childrenCount) {
                    return checkMatchlets(data, matchlet.childrenCount, matchlet.firstChildOffset);
                } else {
                    return true;
                }
            }
        }
        return false;
    }
    
    /**
     * Find all MIME type alternatives for fileName using glob patterns which are not literals or suffices.
     * Params:
     *  fileName = name to match against glob patterns.
     * Returns: Range of MimeTypeAlternativeByName with pattern set to glob pattern matching fileName.
     */
    @trusted auto findMimeTypesByGlob(const(char)[] fileName) const {
        fileName = fileName.baseName;
        return globs().filter!(delegate(GlobEntry glob) { 
            if (glob.cs) {
                return globMatch!(std.path.CaseSensitive.yes)(fileName, glob.glob);
            } else {
                return globMatch!(std.path.CaseSensitive.no)(fileName, glob.glob);
            }
        }).map!(glob => MimeTypeAlternativeByName(glob.mimeType, glob.weight, glob.cs, glob.glob));
    }
    
    /**
     * Find all MIME type alternatives for fileName using literal patterns like Makefile.
     * Params:
     *  fileName = name to match against literal patterns.
     * Returns: Range of MimeTypeAlternativeByName with pattern set to literal matching fileName.
     * Note: Depending on whether found literal is case sensitive or not literal can be equal to base fileName or not.
     */
    @trusted auto findMimeTypesByLiteral(const(char)[] fileName) const {
        return findMimeTypesByLiteralHelper(fileName).map!(literal => MimeTypeAlternativeByName(literal.mimeType, literal.weight, literal.cs, literal.literal));
    }
    
    /**
     * Find all MIME type alternatives for fileName using suffix patterns like *.cpp.
     * Due to mime cache format characteristics it uses output range instead of returning the input one.
     * Params: 
     *  fileName = name to match against suffix patterns.
     *  sink = output range where MimeTypeAlternativeByName objects with pattern set to suffix matching fileName will be put.
     * Note: pattern property of MimeTypeAlternativeByName objects will not have leading "*" to avoid allocating.
     */
    @trusted void findMimeTypesBySuffix(OutRange)(const(char)[] fileName, OutRange sink) const if (isOutputRange!(OutRange, MimeTypeAlternativeByName))
    {
        auto rootCount = readValue!uint(_header.reverseSuffixTreeOffset, "root count");
        auto firstRootOffset = readValue!uint(_header.reverseSuffixTreeOffset + rootCount.sizeof, "first root offset");
        
        lookupLeaf(firstRootOffset, rootCount, fileName, fileName, sink);
    }
    
private:
    @trusted auto magicMatches() const {
        auto matchCount = readValue!uint(_header.magicListOffset, "match count");
        auto maxExtent = readValue!uint(_header.magicListOffset + uint.sizeof, "max extent"); //what is it? Spec does not say anything
        auto firstMatchOffset = readValue!uint(_header.magicListOffset + uint.sizeof*2, "first match offset");
        
        return iota(matchCount)
                .map!(i => firstMatchOffset + i*uint.sizeof*4)
                .map!(offset => MatchEntry(readValue!uint(offset, "weight"), 
                                           readString(readValue!uint(offset+uint.sizeof, "mime type offset"), "mime type name"), 
                                           readValue!uint(offset+uint.sizeof*2, "matchlet count"), 
                                           readValue!uint(offset+uint.sizeof*3, "first matchlet offset")))
                .assumeSorted!(function(a,b) {
                    if (a.weight == b.weight) {
                        return a.mimeType < b.mimeType;
                    } else {
                        return a.weight > b.weight;
                    }
                });
    }
    
    @trusted auto magicMatchlets(uint matchletCount, uint firstMatchletOffset) const {
        return iota(matchletCount)
                .map!(i => firstMatchletOffset + i*uint.sizeof*8)
                .map!(delegate(offset) {
                    uint rangeStart = readValue!uint(offset, "range start");
                    uint rangeLength = readValue!uint(offset+uint.sizeof, "range length");
                    uint wordSize = readValue!uint(offset+uint.sizeof*2, "word size");
                    uint valueLength = readValue!uint(offset+uint.sizeof*3, "value length");
                    
                    uint valueOffset = readValue!uint(offset+uint.sizeof*4, "value offset");
                    const(char)[] value = readString(valueOffset, valueLength, "value");
                    uint maskOffset = readValue!uint(offset+uint.sizeof*5, "mask offset");
                    const(char)[] mask = maskOffset ? readString(maskOffset, valueLength, "mask") : null;
                    uint childrenCount = readValue!uint(offset+uint.sizeof*6, "children count");
                    uint firstChildOffset = readValue!uint(offset+uint.sizeof*7, "first child offset");
                    return MatchletEntry(rangeStart, rangeLength, wordSize, valueLength, value, mask, childrenCount, firstChildOffset);
                });
    }
    
    @trusted auto findMimeTypesByLiteralHelper(const(char)[] name) const {
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
    
    @trusted void lookupLeaf(OutRange)(const uint startOffset, const uint count, const(char[]) originalName, const(char[]) name, OutRange sink, const(char[]) suffix = null, const bool wasCaseMismatch = false) const {
        
        for (uint i=0; i<count; ++i) {
            const size_t offset = startOffset + i * uint.sizeof * 3;
            auto character = readValue!dchar(offset, "character");
            
            if (character) {
                if (name.length) {
                    dchar back = name.back;
                    if (character.toLower == back.toLower) {
                        uint childrenCount = readValue!uint(offset + uint.sizeof, "children count");
                        uint firstChildOffset = readValue!uint(offset + uint.sizeof*2, "first child offset");
                        const(char)[] currentName = name;
                        currentName.popBack();
                        bool caseMismatch = wasCaseMismatch || character != back;
                        lookupLeaf(firstChildOffset, childrenCount, originalName, currentName, sink, originalName[currentName.length..$], caseMismatch);
                    }
                }
            } else {
                uint mimeTypeOffset = readValue!uint(offset + uint.sizeof, "mime type offset");
                auto weightAndCs = readValue!uint(offset + uint.sizeof*2, "weight and flags").parseWeightAndFlags;
                
                auto mimeTypeEntry = MimeTypeAlternativeByName(readString(mimeTypeOffset, "mime type name"), weightAndCs.weight, weightAndCs.cs, suffix);
                
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
        auto parentListCount = readValue!uint(_header.parentListOffset, "parent list count");
        return iota(parentListCount)
                .map!(i => _header.parentListOffset + parentListCount.sizeof + i*uint.sizeof*2)
                .map!(offset => ParentEntry(
                    readString(readValue!uint(offset, "mime type offset"), "mime type name"), 
                    readValue!uint(offset + uint.sizeof, "parents offset")
                ))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }

    @trusted auto commonIcons(uint iconsListOffset) const {
        auto iconCount = readValue!uint(iconsListOffset);
        return iota(iconCount)
                .map!(i => iconsListOffset + iconCount.sizeof + i*uint.sizeof*2)
                .map!(offset => IconEntry(
                    readString(readValue!uint(offset, "mime type offset"), "mime type name"), 
                    readString(readValue!uint(offset+uint.sizeof, "icon name offset"), "icon name")
                ))
                .assumeSorted!(function(a,b) { return a.mimeType < b.mimeType; });
    }
    
    @trusted T readValue(T)(size_t offset, string context = null) const if (isIntegral!T || isSomeChar!T)
    {
        if (_data.length >= offset + T.sizeof) {
            T value = *(cast(const(T)*)_data[offset..(offset+T.sizeof)].ptr);
            static if (endian == Endian.littleEndian) {
                swapByteOrder(value);
            }
            return value;
        } else {
            throw new MimeCacheException("Value is out of bounds", context);
        }
    }
    
    @trusted auto readString(size_t offset, string context = null) const {
        if (offset > _data.length) {
            throw new MimeCacheException("Beginning of string is out of bounds", context);
        }
        
        auto str = cast(const(char[]))_data[offset.._data.length];
        
        size_t len = 0;
        while (len < str.length && str[len] != '\0') {
            ++len;
        }
        if (len == str.length) {
            throw new MimeCacheException("String is not zero terminated", context);
        }
        
        return str[0..len];
    }
    
    @trusted auto readString(size_t offset, uint length, string context = null) const {
        
        if (offset + length <= _data.length) {
            return cast(const(char)[])_data[offset..offset+length];
        } else {
            throw new MimeCacheException("String is out of bounds", context);
        }
    }
    
    MmFile _mmapped;
    const(void)[] _data;
    MimeCacheHeader _header;
    string _fileName;
}
