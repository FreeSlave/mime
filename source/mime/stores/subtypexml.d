/**
 * MIME store implemented around reading of various files in mime/ subfolder.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.stores.subtypexml;

import mime.common;
import mime.store;

private {
    import std.algorithm.iteration : filter, map, joiner;
    import std.array;
    import std.exception : assumeUnique, collectException;
    import std.file : isFile;
    import std.path : buildPath;
    import std.range : retro;
    import std.range.interfaces : inputRangeObject;
    import std.stdio : File;
    import std.typecons;

    import mime.files.types;
    import mime.xml : readMediaSubtypeFile;
}

public import mime.files.common;

/**
 * Implementation of $(D mime.store.IMimeStore) interface that uses MEDIA/SUBTYPE.xml files from mime/ subfolder to read MIME types.
 */
final class MediaSubtypeXmlStore : IMimeStore
{
    /**
     * Params:
     *  mimePaths = Range of paths to base mime directories where mime.cache is usually stored.
     */
    this(string[] mimePaths)
    {
        _mimePaths = mimePaths.dup;
    }

    /**
     * Find and parse MEDIA/SUBTYPE.xml file for given MIME type name.
     * Returns: $(D mime.type.MimeType) object parsed from found xml file(s) or null if no file was found or name is invalid.
     * Throws: $(D mime.xml.XMLMimeException) on format error or $(B std.file.FileException) on file reading error.
     */
    Rebindable!(const(MimeType)) mimeType(const char[] name)
    {
        return rebindable(mimeTypeImpl(name));
    }

    private const(MimeType) mimeTypeImpl(const char[] name)
    {
        if (!isValidMimeTypeName(name))
            return null;
        MimeType* pmimeType = name in _mimeTypes;
        if (pmimeType)
            return *pmimeType;
        foreach(mimePath; _mimePaths.retro)
        {
            auto subtypePath = buildPath(mimePath, assumeUnique(name ~ ".xml"));
            bool isFile;
            collectException(subtypePath.isFile, isFile);
            if (isFile)
            {
                auto mimeType = readMediaSubtypeFile(subtypePath);
                pmimeType = name in _mimeTypes;
                if (pmimeType)
                {
                    mergeMimeTypes(*pmimeType, mimeType);
                }
                else
                {
                    addIconNames(mimeType);
                    _mimeTypes[mimeType.name] = mimeType;
                }
            }
        }
        pmimeType = name in _mimeTypes;
        if (pmimeType)
            return *pmimeType;
        return null;
    }

    /**
     * Lazily read MIME types objects. The list of MIME types is read from mime/types file, so it must be present.
     * Returns: Range of $(D mime.type.MimeType) objects.
     * Throws:
     *  $(D mime.files.common.MimeFileException) on mime/types file parsing error.
     *  $(D mime.xml.XMLMimeException) on xml format error.
     *  $(B std.file.FileException) on file reading error.
     * Note: The resulted range may contain duplicates, if some MIME type has multiple definitions across base mime paths.
     *  The duplicates in this case refer to the same object, i.e. is-equal.
     */
    InputRange!(const(MimeType)) byMimeType() {
        auto typesPaths = _mimePaths.retro.map!(mimePath => buildPath(mimePath, "types")).filter!(delegate(string typesPath) {
            bool isFile;
            collectException(typesPath.isFile, isFile);
            return isFile;
        });

        auto typeNames = typesPaths.map!(typesPath => typesFileReader(File(typesPath, "r").byLineCopy())).joiner;
        auto mimeTypes = typeNames.map!(type => mimeTypeImpl(type)).filter!(mimeType => mimeType !is null);
        return inputRangeObject(mimeTypes);
    }

private:
    @safe void addIconNames(MimeType mimeType)
    {
        if (!mimeType.icon)
            mimeType.icon = defaultIconName(mimeType.name);
        if (!mimeType.genericIcon)
            mimeType.genericIcon = defaultGenericIconName(mimeType.name);
    }
    @safe void mergeMimeTypes(MimeType origin, const(MimeType) additive)
    {
        assert(origin.name == additive.name);
        if (additive.displayName.length)
            origin.displayName = additive.displayName;
        if (additive.icon.length)
            origin.icon = additive.icon;
        if (additive.genericIcon.length)
            origin.genericIcon = additive.genericIcon;
        if (additive.deleteGlobs)
            origin.clearGlobs();
        if (additive.deleteMagic)
            origin.clearMagic();

        foreach(namespace; additive.XMLnamespaces()) {
            origin.addXMLnamespace(namespace);
        }
        foreach(parent; additive.parents()) {
            origin.addParent(parent);
        }
        foreach(aliasName; additive.aliases()) {
            origin.addAlias(aliasName);
        }
        foreach(glob; additive.globs()) {
            origin.addGlob(glob);
        }
        foreach(magic; additive.magics()) {
            origin.addMagic(magic.clone());
        }
        foreach(magic; additive.treeMagics()) {
            origin.addTreeMagic(magic.clone());
        }
    }

    string[] _mimePaths;
    MimeType[const(char)[]] _mimeTypes;
}

unittest
{
    auto mimePaths = ["./test/mime", "./test/discard", "./test/nonexistent"];
    auto store = new MediaSubtypeXmlStore(mimePaths);

    assert(store.mimeType("invalid") is null);
    assert(store.mimeType("application/nonexistent") is null);

    auto sequenceType = store.mimeType("application/x-hlmdl-sequence");
    assert(sequenceType !is null);
    assert(sequenceType.globs == [MimeGlob("*[0123456789][0123456789].mdl", defaultGlobWeight, false)]);
    assert(sequenceType.genericIcon == "application-x-hlmdl");
    assert(sequenceType is store.mimeType("application/x-hlmdl-sequence"));

    auto quakeSprite = store.mimeType("image/x-qsprite");
    assert(quakeSprite !is null);
    assert(quakeSprite.aliases == ["application/x-qsprite"]);

    import std.algorithm.searching : canFind;
    assert(store.byMimeType.canFind!((const(MimeType) type, string name) { return type.name == name; })("application/x-pak"));
}
