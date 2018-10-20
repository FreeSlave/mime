/**
 * Functions for reading XML descriptions of MIME types.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2018
 */

module mime.xml;

import mime.common;

public import mime.type;

private
{
    import dxml.parser;
    import dxml.util;
    import std.conv : to, ConvException;
    import std.exception : assumeUnique;
    import std.mmfile;
    import std.system : Endian, endian;
}

/**
 * Exception that's thrown on invalid XML definition of MIME type.
 */
final class XMLMimeException : Exception
{
    this(string msg, int lineNum, int col, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
        _line = lineNum;
        _col = col;
    }
    private this(string msg, TextPos pos, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        this(msg, pos.line, pos.col, file, line, next);
    }
    private this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        this(msg, 0, 0, file, line, next);
    }

    /// Line number in XML file where error occured. Don't confuse with $(B line) property of $(B Throwable)
    @nogc @safe int lineNum() const nothrow {
        return _line;
    }
    /// Column number in XML file where error occured.
    @nogc @safe int column() const nothrow {
        return _col;
    }

private:
    int _line, _col;
}

private alias EntityRange!(simpleXML, const(char)[]) XmlRange;

private string readSingleAttribute(ref XmlRange.Entity entity, string attrName)
{
    foreach(attr; entity.attributes)
    {
        if (attr.name == attrName)
        {
            return attr.value.idup;
        }
    }
    return null;
}

private void checkXmlRange(ref XmlRange range)
{
    if (range.empty)
        throw new XMLMimeException("Unexpected end of file");
}

private XmlRange.Entity expectOpenTag(ref XmlRange range)
{
    checkXmlRange(range);
    auto elem = range.front;
    if (elem.type != EntityType.elementStart)
        throw new XMLMimeException("Expected an open tag", elem.pos);
    range.popFront();
    return elem;
}

private XmlRange.Entity expectOpenTag(ref XmlRange range, const(char)[] name)
{
    checkXmlRange(range);
    auto elem = range.front;
    if (elem.type != EntityType.elementStart || elem.name != name)
        throw new XMLMimeException(assumeUnique("Expected \"" ~ name ~ "\" open tag"), elem.pos);
    range.popFront();
    return elem;
}

private XmlRange.Entity expectClosingTag(ref XmlRange range, const(char)[] name)
{
    checkXmlRange(range);
    auto elem = range.front;
    if (elem.type != EntityType.elementEnd || elem.name != name)
        throw new XMLMimeException(assumeUnique("Expected \"" ~ name ~ "\" closing tag"), elem.pos);
    range.popFront();
    return elem;
}

private XmlRange.Entity expectTextTag(ref XmlRange range)
{
    checkXmlRange(range);
    auto elem = range.front;
    if (elem.type != EntityType.text)
        throw new XMLMimeException("Expected a text tag", elem.pos);
    range.popFront();
    return elem;
}

/**
 * Get symbolic constant of match type according to the string.
 * Returns: $(D mime.magic.MagicMatch.Type) for passed string, or $(D mime.magic.MagicMatch.Type.string_) if type name is unknown.
 */
@nogc @safe MagicMatch.Type matchTypeFromString(const(char)[] str) pure nothrow
{
    with(MagicMatch.Type) switch(str)
    {
        case "string":
            return string_;
        case "host16":
            return host16;
        case "host32":
            return host32;
        case "big16":
            return big16;
        case "big32":
            return big32;
        case "little16":
            return little16;
        case "little32":
            return little32;
        case "byte":
            return byte_;
        default:
            return string_;
    }
}

///
unittest
{
    assert(matchTypeFromString("string") == MagicMatch.Type.string_);
    assert(matchTypeFromString("little32") == MagicMatch.Type.little32);
    assert(matchTypeFromString("byte") == MagicMatch.Type.byte_);
    assert(matchTypeFromString("") == MagicMatch.Type.string_);
}

private T toNumberValue(T)(const(char)[] valueStr)
{
    if (valueStr.length > 2 && valueStr[0..2] == "0x")
    {
        return valueStr[2..$].to!T(16);
    }
    if (valueStr.length > 1 && valueStr[0] == '0')
    {
        return valueStr[1..$].to!T(8);
    }
    return valueStr.to!T;
}

unittest
{
    assert(toNumberValue!uint("0xFF") == 255);
    assert(toNumberValue!uint("017") == 15);
    assert(toNumberValue!uint("42") == 42);
}

private immutable(ubyte)[] unescapeValue(string value)
{
    import std.array : appender;
    import std.string : representation;
    size_t i = 0;
    for (; i < value.length; i++) {
        if (value[i] == '\\') {
            break;
        }
    }
    if (i == value.length) {
        return value.representation;
    }
    auto toReturn = appender!(immutable(ubyte)[])();
    toReturn.reserve(value.length);
    toReturn.put(value[0..i].representation);
    for (; i < value.length; i++) {
        if (value[i] == '\\' && i+1 < value.length) {
            const char c = value[i+1];
            switch(c)
            {
                case '\\':
                    toReturn.put('\\');
                    ++i;
                    continue;
                case 'n':
                    toReturn.put('\n');
                    ++i;
                    continue;
                case 'r':
                    toReturn.put('\r');
                    ++i;
                    continue;
                case 't':
                    toReturn.put('\t');
                    ++i;
                    continue;
                case 'x':
                {
                    if (i+3 < value.length)
                    {
                        auto hexStr = value[i+2..i+4];
                        toReturn.put(hexStr.to!ubyte(16));
                        i+=3;
                        continue;
                    }
                }
                break;
                default:
                {
                    import std.algorithm.searching : countUntil;
                    import std.ascii : isOctalDigit;
                    auto octalCount = value[i+1..$].countUntil!(a => !isOctalDigit(a));
                    if (octalCount < 0)
                    {
                        octalCount = value.length - (i+1);
                    }
                    if (octalCount == 3)
                    {
                        auto octalStr = value[i+1..i+1+octalCount];
                        toReturn.put(octalStr.to!ubyte(8));
                        i+=octalCount;
                        continue;
                    }
                    else if (octalCount == 1 && value[i+1] == '0')
                    {
                        toReturn.put('\0');
                        ++i;
                        continue;
                    }
                }
                break;
            }
        }
        toReturn.put(value[i]);
    }
    return toReturn.data;
}

unittest
{
    assert(unescapeValue(`\\\n\t\r`) == "\\\n\t\r");
    assert(unescapeValue(`\\xFF`) == "\\xFF");
    assert(unescapeValue(`\x7F`) == [127]);
    assert(unescapeValue(`\177`) == [127]);
    assert(unescapeValue(`\003`) == [3]);
    assert(unescapeValue(`\003vbn`) == [3, 'v', 'b', 'n']);
    assert(unescapeValue(`\0`) == "\0");
    assert(unescapeValue(`no_escape`) == "no_escape");
}

private T swapEndianIfNeeded(T)(T val, Endian expectedEndian)
{
    import std.bitmanip : swapEndian;
    if (endian != expectedEndian)
        return swapEndian(val);
    return val;
}

unittest
{
    assert(swapEndianIfNeeded(42, endian) == 42);
    static if (endian != Endian.bigEndian)
        assert(swapEndianIfNeeded!ushort(10, Endian.bigEndian) == 2560);
}

private Endian endianFromMatchType(MagicMatch.Type type)
{
    with(MagicMatch.Type) switch(type)
    {
        case big16:
        case big32:
            return Endian.bigEndian;
        case little16:
        case little32:
            return Endian.littleEndian;
        default:
            return endian;
    }
}

private immutable(ubyte)[] readMatchValue(const(char)[] valueStr, MagicMatch.Type type, TextPos pos, bool isMask = false)
{
    immutable(ubyte)[] value;
    ubyte val8;
    ushort val16;
    uint val32;
    with(MagicMatch.Type) final switch(type)
    {
        case string_:
            if (isMask)
            {
                import std.array : array;
                import std.algorithm.iteration : map;
                import std.range : chunks;
                import std.utf : byCodeUnit;
                if (valueStr.length > 2 && valueStr[0..2] == "0x")
                {
                    valueStr = valueStr[2..$];
                    if (valueStr.length % 2 == 0)
                    {
                        value = valueStr.byCodeUnit.chunks(2).map!(pair => pair.to!ubyte(16)).array;
                    }
                    else
                    {
                        throw new XMLMimeException("Mask of type string has uneven length", pos);
                    }
                }
                else
                {
                    throw new XMLMimeException("Mask of type string must be in base16 form starting with 0x prefix", pos);
                }
            }
            else
            {
                value = valueStr.idup.decodeXML.unescapeValue;
            }
            break;
        case host16:
        case little16:
        case big16:
            val16 = swapEndianIfNeeded(valueStr.toNumberValue!ushort, endianFromMatchType(type));
            value = (cast(ubyte*)&val16)[0..2].idup;
            break;
        case host32:
        case little32:
        case big32:
            val32 = swapEndianIfNeeded(valueStr.toNumberValue!uint, endianFromMatchType(type));
            value = (cast(ubyte*)&val32)[0..4].idup;
            break;
        case byte_:
            val8 = valueStr.toNumberValue!ubyte;
            value = (&val8)[0..1].idup;
            break;
    }
    return value;
}

private MagicMatch readMagicMatch(ref XmlRange range)
{
    import std.algorithm.searching : findSplit;
    auto elem = expectOpenTag(range, "match");
    try
    {
        static void checkValue(const(char)[] value, string name, TextPos pos)
        {
            if (!value)
                throw new XMLMimeException("Missing \"" ~ name ~ "\" attribute", pos);
        }
        const(char)[] typeStr, valueStr, offset, maskStr;
        getAttrs(elem.attributes, "type", &typeStr, "value", &valueStr, "offset", &offset, "mask", &maskStr);

        checkValue(typeStr, "type", elem.pos);
        checkValue(valueStr, "value", elem.pos);
        checkValue(offset, "offset", elem.pos);

        auto splitted = offset.findSplit(":");
        uint startOffset = splitted[0].to!uint;
        uint rangeLength = 1;
        if (splitted[2].length)
            rangeLength = splitted[2].to!uint;
        immutable(ubyte)[] value, mask;
        auto type = matchTypeFromString(typeStr);
        value = readMatchValue(valueStr, type, elem.pos);
        if (maskStr.length)
            mask = readMatchValue(maskStr, type, elem.pos, true);
        auto magicMatch = MagicMatch(type, value, mask, startOffset, rangeLength);
        while(!range.empty)
        {
            elem = range.front;
            if (elem.type == EntityType.elementEnd && elem.name == "match")
            {
                range.popFront();
                break;
            }
            magicMatch.addSubmatch(readMagicMatch(range));
        }
        return magicMatch;
    }
    catch (ConvException e)
    {
        throw new XMLMimeException(e.msg, elem.pos);
    }
}

/**
 * Get symbolic constant of tree match type according to the string.
 * Returns: $(D mime.treemagic.TreeMatch.Type) for passed string, or $(D mime.treemagic.TreeMatch.Type.any) if type name is unknown.
 */
@nogc @safe TreeMatch.Type treeMatchTypeFromString(const(char)[] str) pure nothrow
{
    with(TreeMatch.Type) switch(str)
    {
        case "file":
            return file;
        case "directory":
            return directory;
        case "link":
            return link;
        default:
            return any;
    }
}

///
unittest
{
    assert(treeMatchTypeFromString("file") == TreeMatch.Type.file);
    assert(treeMatchTypeFromString("directory") == TreeMatch.Type.directory);
    assert(treeMatchTypeFromString("link") == TreeMatch.Type.link);
    assert(treeMatchTypeFromString("") == TreeMatch.Type.any);
}

private TreeMatch readTreeMagicMatch(ref XmlRange range, string mimeTypeName)
{
    import std.algorithm.searching : findSplit;
    auto elem = expectOpenTag(range, "treematch");
    try
    {
        const(char)[] typeStr, pathStr, matchCaseStr, executableStr, nonEmptyStr, mimeTypeStr;
        getAttrs(elem.attributes, "type", &typeStr, "path", &pathStr, "match-case", &matchCaseStr,
                 "executable", &executableStr, "non-empty", &nonEmptyStr, "mimetype", &mimeTypeStr);

        if (!pathStr.length)
            throw new XMLMimeException("Missing \"path\" attribute", elem.pos);

        string path = cast(string)(pathStr.idup.decodeXML.unescapeValue);
        auto type = treeMatchTypeFromString(typeStr);
        auto treeMatch = TreeMatch(path, type);
        treeMatch.executable = executableStr == "true";
        treeMatch.matchCase = matchCaseStr == "true";
        treeMatch.nonEmpty = nonEmptyStr == "true";
        if (mimeTypeStr.length)
            treeMatch.mimeType = mimeTypeStr.idup;

        while(!range.empty)
        {
            elem = range.front;
            if (elem.type == EntityType.elementEnd && elem.name == "treematch")
            {
                range.popFront();
                break;
            }
            treeMatch.addSubmatch(readTreeMagicMatch(range, mimeTypeName));
        }
        return treeMatch;
    }
    catch (ConvException e)
    {
        throw new XMLMimeException(e.msg, elem.pos);
    }
}

private MimeType readMimeType(ref XmlRange range)
{
    typeof(range).Entity elem = expectOpenTag(range, "mime-type");
    string name = readSingleAttribute(elem, "type");
    if (!isValidMimeTypeName(name))
    {
        throw new XMLMimeException("Missing or invalid mime type name", elem.pos);
    }
    auto mimeType = new MimeType(name);
    while(!range.empty)
    {
        if (range.front.type == EntityType.elementEnd && range.front.name == "mime-type")
        {
            range.popFront();
            break;
        }
        elem = expectOpenTag(range);
        const tagName = elem.name;
        switch(elem.name)
        {
            case "glob":
            {
                MimeGlob glob;
                string pattern;
                uint weight = defaultGlobWeight;
                const(char)[] caseSensitive;
                getAttrs(elem.attributes, "pattern", &pattern, "weight", &weight, "case-sensitive", &caseSensitive);
                if (pattern.length == 0)
                {
                    throw new XMLMimeException("Missing pattern in glob declaration", elem.pos);
                }
                else
                {
                    glob.pattern = pattern;
                    glob.weight = weight;
                    glob.caseSensitive = caseSensitive == "true";
                }
                mimeType.addGlob(glob);
                expectClosingTag(range, tagName);
            }
            break;
            case "glob-deleteall":
            {
                mimeType.deleteGlobs = true;
                expectClosingTag(range, tagName);
            }
            break;
            case "magic-deleteall":
            {
                mimeType.deleteMagic = true;
                expectClosingTag(range, tagName);
            }
            break;
            case "alias":
            {
                string aliasName = readSingleAttribute(elem, "type");
                if (!isValidMimeTypeName(aliasName))
                {
                    throw new XMLMimeException("Missing or invalid alias name", elem.pos);
                }
                mimeType.addAlias(aliasName);
                expectClosingTag(range, tagName);
            }
            break;
            case "sub-class-of":
            {
                string parentName = readSingleAttribute(elem, "type");
                if (!isValidMimeTypeName(parentName))
                {
                    throw new XMLMimeException("Missing or invalid parent name", elem.pos);
                }
                mimeType.addParent(parentName);
                expectClosingTag(range, tagName);
            }
            break;
            case "comment":
            {
                bool localized = false;
                foreach(attr; elem.attributes)
                {
                    if (attr.name == "xml:lang")
                    {
                        localized = true;
                        break;
                    }
                }
                elem = expectTextTag(range);
                if (!localized)
                {
                    mimeType.displayName = elem.text.idup.decodeXML;
                }
                expectClosingTag(range, tagName);
            }
            break;
            case "icon":
            {
                string icon = readSingleAttribute(elem, "name");
                mimeType.icon = icon;
                expectClosingTag(range, tagName);
            }
            break;
            case "generic-icon":
            {
                string genericIcon = readSingleAttribute(elem, "name");
                mimeType.genericIcon = genericIcon;
                expectClosingTag(range, tagName);
            }
            break;
            case "root-XML":
            {
                string namespaceURI, localName;
                getAttrs(elem.attributes, "namespaceURI", &namespaceURI, "localName", &localName);
                mimeType.addXMLnamespace(namespaceURI, localName);
                expectClosingTag(range, tagName);
            }
            break;
            case "magic":
            {
                uint priority = defaultMatchWeight;
                getAttrs(elem.attributes, "priority", &priority);
                auto magic = MimeMagic(priority);
                while (!range.empty)
                {
                    elem = range.front;
                    if (elem.type == EntityType.elementEnd && elem.name == "magic")
                    {
                        mimeType.addMagic(magic);
                        range.popFront();
                        break;
                    }
                    magic.addMatch(readMagicMatch(range));
                }
            }
            break;
            case "treemagic":
            {
                uint priority = defaultMatchWeight;
                getAttrs(elem.attributes, "priority", &priority);
                auto treeMagic = TreeMagic(priority);
                while (!range.empty)
                {
                    elem = range.front;
                    if (elem.type == EntityType.elementEnd && elem.name == "treemagic")
                    {
                        mimeType.addTreeMagic(treeMagic);
                        range.popFront();
                        break;
                    }
                    treeMagic.addMatch(readTreeMagicMatch(range, name));
                }
            }
            break;
            default:
            {
                while(!range.empty)
                {
                    elem = range.front;
                    range.popFront();
                    if (elem.type == EntityType.elementEnd && elem.name == tagName)
                    {
                        break;
                    }
                }
            }
            break;
        }
    }
    return mimeType;
}

/**
 * Read MIME type from MEDIA/SUBTYPE.xml file (e.g. image/png.xml).
 * Returns: $(D mime.type.MimeType) parsed from xml definition.
 * Throws: $(D mime.xml.XMLMimeException) on format error or $(B std.file.FileException) on file reading error.
 * See_Also: $(D mime.xml.readMediaSubtypeXML)
 * Note: According to the spec MEDIA/SUBTYPE.xml files have magic, root-XML and glob fields removed.
 *  In reality glob fields stay untouched, but this may change in future and this behavior should not be relied on.
 */
@trusted MimeType readMediaSubtypeFile(string filePath)
{
    auto mmFile = new MmFile(filePath);
    scope(exit) destroy(mmFile);
    auto data = cast(const(char)[])mmFile[];
    return readMediaSubtypeXML(data);
}

/**
 * Read MIME type from xml formatted data with mime-type root element as defined by spec.
 * Returns: $(D mime.type.MimeType) parsed from xml definition.
 * Throws: $(D XMLMimeException) on format error.
 * See_Also: $(D mime.xml.readMediaSubtypeFile)
 */
@trusted MimeType readMediaSubtypeXML(const(char)[] xmlData)
{
    try
    {
        auto range = parseXML!simpleXML(xmlData);
        return readMimeType(range);
    }
    catch(XMLParsingException e)
    {
        throw new XMLMimeException(e.msg, e.pos);
    }
}

///
unittest
{
    auto xmlData = `<?xml version="1.0" encoding="utf-8"?>
<mime-type xmlns="http://www.freedesktop.org/standards/shared-mime-info" type="text/markdown">
  <!--Created automatically by update-mime-database. DO NOT EDIT!-->
  <comment>Markdown document</comment>
  <comment xml:lang="ru">документ Markdown</comment>
  <sub-class-of type="text/plain"/>
  <x-unknown>Just for a test</x-unknown>
  <glob pattern="*.md"/>
  <glob pattern="*.mkd" weight="40"/>
  <glob pattern="*.markdown" case-sensitive="true"/>
  <alias type="text/x-markdown"/>
</mime-type>`;
    auto mimeType = readMediaSubtypeXML(xmlData);
    assert(mimeType.name == "text/markdown");
    assert(mimeType.displayName == "Markdown document");
    assert(mimeType.aliases == ["text/x-markdown"]);
    assert(mimeType.parents == ["text/plain"]);
    assert(mimeType.globs == [MimeGlob("*.md"), MimeGlob("*.mkd", 40), MimeGlob("*.markdown", defaultGlobWeight, true)]);

    import std.exception : assertThrown, assertNotThrown;
    auto notXml = "not xml";
    assertThrown!XMLMimeException(readMediaSubtypeXML(notXml));
    auto invalidEmpty = `<?xml version="1.0" encoding="utf-8"?>`;
    assertThrown!XMLMimeException(readMediaSubtypeXML(invalidEmpty));

    auto notNumber = `<mime-type type="text/markdown">
  <glob pattern="*.mkd" weight="not_a_number"/>
</mime-type>`;
    assertThrown!XMLMimeException(readMediaSubtypeXML(notNumber));

    auto validEmpty = `<mime-type type="text/markdown"></mime-type>`;
    assertNotThrown(readMediaSubtypeXML(validEmpty));

    auto missingName = `<mime-type></mime-type>`;
    assertThrown(readMediaSubtypeXML(missingName));

    auto noPattern = `<mime-type type="text/markdown">
  <glob pattern=""/></mime-type>`;
    assertThrown!XMLMimeException(readMediaSubtypeXML(noPattern));
}

struct XMLPackageRange
{
    private this(const(char)[] data)
    {
        this.data = data;
        this(parseXML!simpleXML(this.data));
    }
    private this(MmFile mmFile)
    {
        assert(mmFile !is null);
        this.mmFile = mmFile;
        this(cast(const(char)[])this.mmFile[]);
    }
    private this(XmlRange range)
    {
        this.range = range;
        expectOpenTag(this.range, "mime-info");
    }
    MimeType front()
    {
        if (mimeType)
            return mimeType;
        try
        {
            mimeType = readMimeType(range);
        }
        catch(XMLParsingException e)
        {
            throw new XMLMimeException(e.msg, e.pos);
        }
        return mimeType;
    }
    void popFront()
    {
        mimeType = null;
    }
    bool empty()
    {
        if (mimeType !is null)
            return false;
        if (range.empty || end)
            return true;
        auto elem = range.front;
        if (elem.type == EntityType.elementEnd && elem.name == "mime-info")
        {
            range.popFront();
            end = true;
            return true;
        }
        return false;
    }
    auto save()
    {
        return this;
    }
private:
    MmFile mmFile;
    const(char)[] data;
    XmlRange range;
    MimeType mimeType;
    bool end;
}

/**
 * Lazily read MIME types from packages/package_name.xml file (e.g. packages/freedesktop.org.xml).
 * Returns: Forward range of $(D mime.type.MimeType) elements parsed from xml definition.
 * Throws: $(D mime.xml.XMLMimeException) on format error or $(B std.file.FileException) on file reading error.
 * See_Also: $(D mime.xml.readMimePackageXML)
 * Note: Package files are source files. They may be not synced with output files produced by $(B update-mime-database)
 *  (e.g. if source file had been changed, but the mentioned utility was not called after that)
 *  Source files however contain the most complete definition of MIME type including globs, magic rules and XML namespaces.
 */
XMLPackageRange readMimePackageFile(string filePath)
{
    auto mmFile = new MmFile(filePath);
    try
    {
        return XMLPackageRange(mmFile);
    }
    catch(XMLParsingException e)
    {
        throw new XMLMimeException(e.msg, e.pos);
    }
}

unittest
{
    string filePath = "./test/mime/packages/base.xml";
    auto range = readMimePackageFile(filePath);
    assert(!range.empty);
    auto mimeType = range.front;
    auto range2 = range.save;
    range.popFront();
    assert(range2.front is mimeType);
    assert(range2.front !is range.front);
}

/**
 * Read MIME types from xml formatted data with mime-info root element as defined by spec.
 * Returns: Forward range of $(D mime.type.MimeType) elements parsed from xml definition.
 * Throws: $(D XMLMimeException) on format error.
 * See_Also: $(D mime.xml.readMimePackageFile)
 */
XMLPackageRange readMimePackageXML(string xmlData)
{
    try
    {
        return XMLPackageRange(xmlData);
    }
    catch(XMLParsingException e)
    {
        throw new XMLMimeException(e.msg, e.pos);
    }
}

///
unittest
{
    string xmlData = `<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="image/x-sigma-x3f">
        <comment>Sigma X3F raw image</comment>
        <sub-class-of type="image/x-dcraw"/>
        <magic-deleteall/>
        <magic priority="60">
            <match value="FOVb" type="string" offset="0">
                <match value="0x00FF00FF" type="little32" offset="4" mask="0xFF00FF00"/>
            </match>
        </magic>
        <glob-deleteall/>
        <glob pattern="*.x3f"/>
    </mime-type>
        <mime-type type="image/svg+xml">
        <comment>SVG image</comment>
        <sub-class-of type="application/xml"/>
        <magic priority="80">
            <match value="&lt;!DOCTYPE svg" type="string" offset="0:256"/>
            <match value="&lt;svg" type="string" offset="0:256"/>
        </magic>
        <glob pattern="*.svg"/>
        <root-XML namespaceURI="http://www.w3.org/2000/svg" localName="svg"/>
    </mime-type>
    <mime-type type="x-content/video-bluray">
        <comment>Blu-ray video disc</comment>
        <treemagic>
        <treematch type="directory" path="BDAV" non-empty="true" match-case="true"/>
        <treematch type="directory" path="BDMV" non-empty="true"/>
        </treemagic>
    </mime-type>
    <mime-type type="application/x-sharedlib">
        <magic priority="50">
            <match value="\177ELF            \003" type="string" offset="0" mask="0xffffffff000000000000000000000000ff"/>
        </magic>
    </mime-type>
</mime-info>`;
    auto range = readMimePackageXML(xmlData);
    assert(!range.empty);
    auto mimeType = range.front;
    assert(mimeType is range.front);
    assert(mimeType.name == "image/x-sigma-x3f");
    assert(mimeType.deleteMagic);
    assert(mimeType.deleteGlobs);
    assert(mimeType.magics.length == 1);
    auto magic = mimeType.magics[0];
    assert(magic.weight == 60);
    assert(magic.matches.length == 1);
    auto match = magic.matches[0];
    assert(match.type == MagicMatch.Type.string_);
    assert(match.value == "FOVb");
    assert(match.submatches.length == 1);
    auto submatch = match.submatches[0];
    assert(submatch.type == MagicMatch.Type.little32);
    const uint val = 0x00FF00FF;
    const uint mask = 0xFF00FF00;
    import std.bitmanip : nativeToLittleEndian;
    auto valArr = nativeToLittleEndian(val);
    auto maskArr = nativeToLittleEndian(mask);
    assert(submatch.value == valArr[]);
    assert(submatch.mask == maskArr[]);

    range.popFront();
    assert(!range.empty);

    mimeType = range.front;
    assert(mimeType.XMLnamespaces == [XMLnamespace("http://www.w3.org/2000/svg", "svg")]);
    assert(mimeType.name == "image/svg+xml");
    assert(mimeType.magics.length == 1);
    auto magic2 = mimeType.magics[0];
    assert(magic2.weight == 80);
    assert(magic2.matches.length == 2);
    auto match2 = magic2.matches[1];
    assert(match2.type == MagicMatch.Type.string_);
    assert(match2.value == "<svg");

    range.popFront();
    assert(!range.empty);

    mimeType = range.front;
    assert(mimeType.name == "x-content/video-bluray");
    assert(mimeType.treeMagics.length == 1);
    auto treeMagic = mimeType.treeMagics[0];
    assert(treeMagic.matches.length == 2);
    auto treeMatch = treeMagic.matches[0];
    assert(treeMatch.path == "BDAV");
    assert(treeMatch.nonEmpty);
    assert(treeMatch.matchCase);

    range.popFront();

    mimeType = range.front;
    assert(mimeType);
    assert(mimeType.magics.length == 1);
    auto magic3 = mimeType.magics[0];
    assert(magic3.matches.length == 1);
    auto match3 = magic3.matches[0];
    assert(match3.mask == "\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff");

    range.popFront();
    assert(range.empty);
    assert(range.empty);

    import std.exception : collectException;
    xmlData = `<?xml version="1.0" encoding="utf-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/x-sharedlib">
        <magic priority="50">
            <match value="\177ELF            \003" type="string" offset="0" mask="wrong_format"/>
        </magic>
    </mime-type>
</mime-info>`;
    range = readMimePackageXML(xmlData);
    assert(!range.empty);
    auto e = collectException!XMLMimeException(range.front);
    assert(e !is null);
    assert(e.lineNum == 5);
}

/**
 * Get XML namespace from text data. The text is not required to be a data of the whole file.
 * Note however that some xml files may contain a big portion of DOCTYPE declaration at the start.
 * Returns: xmlns attribute of the root xml element or null if text is not xml-formatted or does not have a namespace.
 * See_Also: $(D mime.xml.getXMLnamespaceFromFile)
 */
string getXMLnamespaceFromData(const(char)[] xmlData)
{
    import std.utf : UTFException;
    try
    {
        auto range = parseXML!simpleXML(xmlData);
        checkXmlRange(range);
        auto root = range.front;
        string xmlns;
        getAttrs(root.attributes, "xmlns", &xmlns);
        return xmlns;
    }
    catch(XMLParsingException e)
    {
        return null;
    }
    catch(UTFException e)
    {
        return null;
    }
}

///
unittest
{
    auto xmlData = `<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">`;
    assert(getXMLnamespaceFromData(xmlData) == "http://www.freedesktop.org/standards/shared-mime-info");
    assert(getXMLnamespaceFromData("<start-element>") == string.init);
    assert(getXMLnamespaceFromData("") == string.init);
}

/**
 * Get XML namespace of file.
 * Throws: $(B std.file.FileException) on file reading error.
 * See_Also: $(D mime.xml.getXMLnamespaceFromData)
 */
string getXMLnamespaceFromFile(string fileName, size_t upTo = dataSizeToRead)
{
    import std.file : read;
    auto xmlData = cast(const(char)[])read(fileName, upTo);
    return getXMLnamespaceFromData(xmlData);
}

unittest
{
    string filePath = "./test/mime/packages/base.xml";
    assert(getXMLnamespaceFromFile(filePath).length);
}
