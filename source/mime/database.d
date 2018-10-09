/**
 * Access to Shared MIME-info database.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 * See_Also: $(LINK2 https://www.freedesktop.org/wiki/Specifications/shared-mime-info-spec/, Shared MIME database specification)
 */

module mime.database;

import std.range;
import std.typecons;

import mime.store;
import mime.detector;
import mime.text;
import mime.inode;

import mime.common : dataSizeToRead;
public import mime.type;

/**
 * High-level class for accessing Shared MIME-info database.
 */
final class MimeDatabase
{
    /// Options for $(D mimeTypeForFile)
    enum Match
    {
        globPatterns = 1,   /// Match file name against glob patterns.
        magicRules   = 2,   /// Match file content against magic rules. With MatchOptions.globPatterns flag it's used only in conflicts.
        namespaceURI = 4, /// Try to clarify mime type in case it's XML.
        inodeType = 8, /// Provide inode/* type for files other than regular files.
        textFallback = 16, /// Provide $(D text/plain) fallback if data seems to be textual.
        octetStreamFallback = 32, /// Provide $(D application/octet-stream) fallback if data seems to be binary.
        emptyFileFallback = 64, ///Provide $(B application/x-zerosize) fallback if mime type can't be detected, but data is known to be zero size.
        all = globPatterns|magicRules|namespaceURI|inodeType|textFallback|octetStreamFallback|emptyFileFallback ///Use all recipes to detect MIME type.
    }

    /**
     * Constructor based on MIME paths.
     * It uses $(D mime.detectors.cache.MimeDetectorFromCache) as MIME type detector and $(D mime.stores.files.FilesMimeStore) as MIME type store.
     * Params:
     *  mimePaths = Range of paths to base mime directories where needed files will be read.
     * See_Also: $(D mime.paths.mimePaths), $(D mime.detectors.cache.MimeDetectorFromCache), $(D mime.stores.files.FilesMimeStore)
     */
    this(Range)(Range mimePaths) if (isInputRange!Range && is(ElementType!Range : string))
    {
        import mime.stores.subtypexml;
        import mime.detectors.cache;

        _store = new MediaSubtypeXmlStore(mimePaths);
        _detector = new MimeDetectorFromCache(mimePaths);
    }

    /**
     * Create MimeDatabase object with given store and detector.
     */
    @safe this(IMimeStore store, IMimeDetector detector)
    {
        _store = store;
        _detector = detector;
    }

    /**
     * Get MIME types store used in MimeDatabase instance.
     */
    IMimeStore store()
    {
        return _store;
    }

    /**
     * Get MIME type detector used in MimeDatabase instance.
     */
    IMimeDetector detector()
    {
        return _detector;
    }

    /**
     * Get MIME type for given fileName.
     * See_Also: $(D mimeTypeForFile)
     */
    Rebindable!(const(MimeType)) mimeTypeForFileName(string fileName)
    {
        return findExistingAlternative(_detector.mimeTypesForFileName(fileName));
    }

    /**
     * Get MIME type for given data.
     * Note: This does NOT provide any fallbacks like text/plain, application/octet-stream or application/x-zerosize.
     * See_Also: $(D mimeTypeForFile)
     */
    Rebindable!(const(MimeType)) mimeTypeForData(const(void)[] data)
    {
        return findExistingAlternative(_detector.mimeTypesForData(data));
    }

    /**
     * Get MIME type for file and its data using methods describing in options.
     * Params:
     *  fileName = Name of file
     *  data = Data chunk read from the file. It's not necessary to read the whole file.
     *  options = Lookup options
     */
    Rebindable!(const(MimeType)) mimeTypeForFile(string fileName, const(void)[] data, Match options = Match.all)
    {
        return mimeTypeForFileImpl(fileName, data, options, true);
    }

    /**
     * Get MIME type for file using methods describing in options.
     * File contents will be read automatically if needed.
     */
    Rebindable!(const(MimeType)) mimeTypeForFile(string fileName, Match options = Match.all)
    {
        return mimeTypeForFileImpl(fileName, null, options, false);
    }

    private auto checkIfXml(string fileName, const(void)[] data, const bool dataPassed)
    {
        static import std.file;
        import mime.xml : getXMLnamespaceFromData;
        if (!dataPassed)
        {
            try {
                data = std.file.read(fileName, dataSizeToRead);
            } catch(Exception e) {
                return rebindable(const(MimeType).init);
            }
        }
        string namespaceURI = getXMLnamespaceFromData(cast(const(char)[])data);
        if (namespaceURI.length)
        {
            auto name = _detector.mimeTypeForNamespaceURI(namespaceURI);
            return mimeType(name, No.resolveAlias);
        }
        return rebindable(const(MimeType).init);
    }

    private auto mimeTypeForFileImpl(string fileName, const(void)[] data, Match options, bool dataPassed)
    {
        auto type = mimeTypeForFileImplRef(fileName, data, options, dataPassed);
        if ((options & Match.namespaceURI) != 0 && type && type.name == "application/xml")
        {
            auto xmlType = checkIfXml(fileName, data, dataPassed);
            if (xmlType)
                return xmlType;
        }
        return type;
    }

    private auto mimeTypeForFileImplRef(string fileName, ref const(void)[] data, Match options, ref bool dataPassed)
    {
        static import std.file;
        import std.file : getSize;
        import std.exception : collectException;

        if (data is null && (options & Match.inodeType)) {
            string inodeType = inodeMimeType(fileName);
            if (inodeType.length) {
                return mimeType(inodeType);
            }
        }

        const(char[])[] mimeTypes;
        if (options & Match.globPatterns) {
            mimeTypes = _detector.mimeTypesForFileName(fileName);
            if (mimeTypes.length == 1) {
                auto type = mimeType(mimeTypes[0]);
                if (type !is null) {
                    return type;
                }
            }
        }

        if ((options & Match.emptyFileFallback) && mimeTypes.length == 0) {
            if (!dataPassed) {
                ulong size;
                auto e = collectException(fileName.getSize, size);
                if (e is null && size == 0) {
                    return mimeType("application/x-zerosize");
                }
            } else {
                if (data.length == 0) {
                    return mimeType("application/x-zerosize");
                }
            }
        }

        if (!dataPassed && (options & (Match.magicRules|Match.textFallback|Match.octetStreamFallback))) {
            try {
                data = std.file.read(fileName, dataSizeToRead);
            } catch(Exception e) {
                //pass
            }
        }

        if (data.length && (options & Match.magicRules)) {
            auto conflicts = _detector.mimeTypesForData(data);
            auto type = findExistingAlternative(conflicts);
            if (type !is null) {
                return type;
            }
        }
        if (mimeTypes.length) {
            auto type = findExistingAlternative(mimeTypes);
            if (type) {
                return type;
            }
        }
        if (data.length && (options & Match.textFallback) && isTextualData(data)) {
            return mimeType("text/plain");
        }
        if (data.length && (options & Match.octetStreamFallback)) {
            return mimeType("application/octet-stream");
        }

        return rebindable(const(MimeType).init);
    }

    private auto findExistingAlternative(const(char[])[] conflicts)
    {
        foreach(name; conflicts) {
            auto type = mimeType(name);
            if (type !is null) {
                return type;
            }
        }
        return rebindable(const(MimeType).init);
    }

    /**
     * Get mime type by name or alias.
     * Params:
     *  nameOrAlias = MIME type name or alias.
     *  resolve = Try to resolve alias if could not find MIME type with given name.
     * Returns: $(D mime.type.MimeType) for given nameOrAlias, resolving alias if needed. Null if no mime type found.
     */
    Rebindable!(const(MimeType)) mimeType(const(char)[] nameOrAlias, Flag!"resolveAlias" resolve = Yes.resolveAlias)
    {
        if (nameOrAlias.length == 0) {
            return rebindable(const(MimeType).init);
        }
        auto type = _store.mimeType(nameOrAlias);
        if (type is null && resolve) {
            auto resolved = _detector.resolveAlias(nameOrAlias);
            if (resolved.length) {
                type = _store.mimeType(resolved);
            }
        }
        return type;
    }

private:
    IMimeStore _store;
    IMimeDetector _detector;
}

///
unittest
{
    import mime.stores.files;
    import mime.detectors.cache;

    auto mimePaths = ["./test/mime", "./test/discard", "./test/nonexistent"];

    alias FilesMimeStore.Options FOptions;
    FOptions foptions;
    ubyte opt = FOptions.required;

    foptions.types = opt;
    foptions.aliases = opt;
    foptions.subclasses = opt;
    foptions.icons = opt;
    foptions.genericIcons = opt;
    foptions.XMLnamespaces = opt;
    foptions.globs2 = opt;
    foptions.globs = opt;
    foptions.magic = opt;
    foptions.treemagic = opt;

    auto store = new FilesMimeStore(mimePaths, foptions);
    assert(!store.byMimeType().empty);
    auto detector = new MimeDetectorFromCache(mimePaths);

    assert(detector.mimeCaches().length == 2);
    assert(detector.mimeTypeForFileName("sprite.spr").length);
    assert(detector.mimeTypeForFileName("model01.mdl").length);
    assert(detector.mimeTypeForFileName("liblist.gam").length);
    assert(detector.mimeTypeForFileName("no.exist").empty);
    assert(detector.mimeTypeForData("IDSP\x02\x00\x00\x00") == "image/x-hlsprite");
    assert(detector.resolveAlias("application/nonexistent") is null);

    assert(detector.mimeTypeForNamespaceURI("http://www.w3.org/1999/ent") == "text/x-ent");
    assert(detector.mimeTypeForNamespaceURI("nonexistent").empty);

    auto database = new MimeDatabase(store, detector);
    assert(database.detector() is detector);
    assert(database.store() is store);

    assert(database.mimeType(string.init) is null);

    auto imageSprite = database.mimeType("image/x-hlsprite");
    auto appSprite = database.mimeType("application/x-hlsprite");
    assert(database.mimeType("application/x-hlsprite", No.resolveAlias) is null);
    assert(imageSprite !is null && imageSprite is appSprite);

    assert(database.detector().isSubclassOf("text/x-fgd", "text/plain"));
    assert(!database.detector().isSubclassOf("text/x-fgd", "application/octet-stream"));

    auto fgdType = database.mimeTypeForFileName("name.fgd");
    assert(fgdType !is null);
    assert(fgdType.name == "text/x-fgd");

    //testing Match options
    auto iqm = database.mimeTypeForFile("model.iqm", MimeDatabase.Match.globPatterns);
    assert(iqm !is null);
    assert(iqm.name == "application/x-iqm");

    auto spriteType = database.mimeTypeForFile("sprite.spr", MimeDatabase.Match.globPatterns);
    assert(spriteType !is null);

    auto sprite32 = database.mimeTypeForFile("sprite.spr", "IDSP\x20\x00\x00\x00", MimeDatabase.Match.magicRules);
    assert(sprite32 !is null);
    assert(sprite32.name == "image/x-sprite32");

    auto zeroType = database.mimeTypeForFile("nonexistent", (void[]).init, MimeDatabase.Match.emptyFileFallback);
    assert(zeroType !is null);
    assert(zeroType.name == "application/x-zerosize");

    zeroType = database.mimeTypeForFile("test/emptyfile", MimeDatabase.Match.emptyFileFallback);
    assert(zeroType !is null);
    assert(zeroType.name == "application/x-zerosize");

    auto textType = database.mimeTypeForFile("test/mime/types", MimeDatabase.Match.textFallback);
    assert(textType !is null);
    assert(textType.name == "text/plain");

    auto dirType = database.mimeTypeForFile("test", MimeDatabase.Match.inodeType);
    assert(dirType !is null);
    assert(dirType.name == "inode/directory");

    auto octetStreamType = database.mimeTypeForFile("test/mime/mime.cache", MimeDatabase.Match.octetStreamFallback);
    assert(octetStreamType !is null);
    assert(octetStreamType.name == "application/octet-stream");

    assert(database.mimeTypeForFile("file.unknown", MimeDatabase.Match.globPatterns) is null);

    //testing data
    auto hlsprite = database.mimeTypeForData("IDSP\x02\x00\x00\x00");
    assert(hlsprite !is null);
    assert(hlsprite.name == "image/x-hlsprite");

    auto qsprite = database.mimeTypeForData("IDSP\x01\x00\x00\x00");
    assert(qsprite !is null);
    assert(qsprite.name == "image/x-qsprite");

    auto q2sprite = database.mimeTypeForData("IDS2");
    assert(q2sprite !is null);
    assert(q2sprite.name == "image/x-q2sprite");

    //testing case-insensitive suffix
    auto vpk = database.mimeTypeForFileName("pakdir.vpk");
    assert(vpk !is null);
    assert(vpk.name == "application/vnd.valve.vpk");

    vpk = database.mimeTypeForFileName("pakdir.VPK");
    assert(vpk !is null);
    assert(vpk.name == "application/vnd.valve.vpk");

    //testing generic glob
    auto modelseq = database.mimeTypeForFileName("model01.mdl");
    assert(modelseq !is null);
    assert(modelseq.name == "application/x-hlmdl-sequence");
    modelseq = database.mimeTypeForFileName("model01.MDL");
    assert(modelseq !is null && modelseq.name == "application/x-hlmdl-sequence");

    auto generalGlob = database.mimeTypeForFileName("general_test_long_glob");
    assert(generalGlob !is null);
    assert(generalGlob.name == "application/x-general-long-glob");
    assert(database.detector.mimeTypeForFileName("general_test_long_glob"));

    assert(!database.mimeTypeForFileName("pak1.PAK"));
    assert(database.mimeTypeForFileName("pak1.pak"));

    //testing case-sensitive suffix
    assert(database.mimeTypeForFileName("my.shader"));
    assert(!database.mimeTypeForFileName("my.SHADER"));

    //testing literal
    assert(database.mimeTypeForFileName("liblist.gam"));
    assert(database.mimeTypeForFileName("makefile"));

    //testing discard glob
    assert(!database.mimeTypeForFileName("GNUmakefile"));
    assert(!database.detector.mimeTypeForFileName("GNUmakefile"));

    assert(!database.mimeTypeForFileName("file.qvm3"));
    assert(!database.detector.mimeTypeForFileName("file.qvm3"));

    assert(!database.mimeTypeForFileName("model01.sequence"));
    assert(!database.detector.mimeTypeForFileName("model01.sequence"));

    //testing discard magic
    assert(!database.mimeTypeForData("PAK"));
    assert(!database.detector.mimeTypeForData("PAK"));
    assert(!database.mimeTypeForFileName("file.qwad"));

    //conflicts
    assert(database.mimeTypeForFileName("file.jmf"));
    assert(database.mimeTypeForData("PACK"));

    //xml
    assert(database.mimeTypeForFileName("file.xml").name == "application/xml");
    assert(database.mimeTypeForData("<?xml").name == "application/xml");
    assert(database.mimeTypeForFile("file.xml", `<start-element xmlns="http://www.w3.org/1999/ent">`).name == "text/x-ent");
}
