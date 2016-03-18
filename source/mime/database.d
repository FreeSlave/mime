/**
 * Access to Shared MIME-info database.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.database;

import std.range;

import mime.store;
import mime.detector;
import mime.type;
import mime.text;
import mime.inode;

/**
 * High-level class for accessing Shared MIME-info database.
 */
final class MimeDatabase
{
    /// Options for mimeTypeForFile
    enum Match
    {
        globPatterns = 1,   /// Match file name against glob patterns.
        magicRules   = 2,   /// Match file content against magic rules. With MatchOptions.globPatterns flag it's used only in conflicts.
        //namespaceUri = 4, /// Try to clarify mime type in case it's XML.
        inodeType = 8, /// Provide inode/* type for files other than regular files.
        textFallback = 16, /// Provide text/plain fallback if data seems to be textual.
        octetStreamFallback = 32, /// Provide application/octet-stream fallback if data seems to be binary.
        emptyFileFallback = 64 ///Provide application/x-zerosize fallback if mime type can't be detected, but data is known to be zero size.
    }
    
    /**
     * Constructor based on MIME paths. 
     * It uses mime.detectors.cache.MimeDetectorFromCache as MIME type detector and mime.stores.files.FilesMimeStore as MIME type store.
     * Params:
     *  mimePaths = Range of paths to base mime directories where needed files will be read.
     * See_Also: mime.paths.mimePaths, mime.detectors.cache.MimeDetectorFromCache, mime.stores.files.FilesMimeStore
     */
    this(Range)(Range mimePaths) if (isInputRange!Range && is(ElementType!Range : string))
    {
        import mime.stores.files;
        import mime.detectors.cache;
        
        _store = new FilesMimeStore(mimePaths);
        _detector = new MimeDetectorFromCache(mimePaths);
    }
    
    /**
     * Create MimeDatabase object with given store and detector.
     */
    this(IMimeStore store, IMimeDetector detector)
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
     */
    Rebindable!(const(MimeType)) mimeTypeForFileName(string fileName)
    {
        return findExistingAlternative(_detector.mimeTypesForFileName(fileName));
    }
    
    /**
     * Get MIME type for given data.
     */
    Rebindable!(const(MimeType)) mimeTypeForData(const(void)[] data)
    {
        return findExistingAlternative(_detector.mimeTypesForData(data));
    }
    
    /**
     * Get MIME type for file using methods describing in options.
     */
    Rebindable!(const(MimeType)) mimeTypeForFile(string fileName, const(void)[] data, Match options = Match.globPatterns|Match.magicRules|Match.octetStreamFallback|Match.textFallback)
    {
        return mimeTypeForFileImpl(fileName, data, options);
    }
    
    /**
     * Get MIME type for file using methods describing in options.
     * File contents will be read automatically if needed.
     */
    Rebindable!(const(MimeType)) mimeTypeForFile(string fileName, Match options = Match.globPatterns|Match.magicRules|Match.octetStreamFallback|Match.textFallback)
    {
        return mimeTypeForFileImpl(fileName, null, options);
    }
    
    private auto mimeTypeForFileImpl(string fileName, const(void)[] data, Match options)
    {
        import std.file;
        import std.exception;
        
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
        
        if (data is null && (options & Match.emptyFileFallback) && mimeTypes.length == 0) {
            ulong size;
            auto e = collectException(fileName.getSize, size);
            if (e is null && size == 0) {
                return mimeType("application/x-zerosize");
            }
        }
        
        if (data is null && (options & (Match.magicRules | Match.textFallback | Match.octetStreamFallback ))) {
            try {
                data = std.file.read(fileName, 256);
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
     * Returns: mime.type.MimeType object for given nameOrAlias, resolving alias if needed. Null if no mime type found.
     */
    Rebindable!(const(MimeType)) mimeType(const(char)[] nameOrAlias)
    {
        if (nameOrAlias.length == 0) {
            return rebindable(const(MimeType).init);
        }
        auto type = _store.mimeType(nameOrAlias);
        if (type is null) {
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
    
    auto mimePaths = ["./test/mime"];
    
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
    
    auto store = new FilesMimeStore(mimePaths, foptions);
    auto detector = new MimeDetectorFromCache(mimePaths);
    
    assert(detector.mimeCaches().length == 1);
    assert(detector.mimeTypeForFileName("sprite.spr").length);
    assert(detector.mimeTypeForFileName("model01.mdl").length);
    assert(detector.mimeTypeForFileName("no.exist").empty);
    assert(detector.mimeTypeForData("IDSP\x02\x00\x00\x00") == "image/x-hlsprite");
    
    auto database = new MimeDatabase(store, detector);
    
    auto imageSprite = database.mimeType("image/x-hlsprite");
    auto appSprite = database.mimeType("application/x-hlsprite");
    assert(imageSprite !is null && imageSprite is appSprite);
    
    assert(database.detector().isSubclassOf("text/x-fgd", "text/plain"));
    auto fgdType = database.mimeTypeForFileName("name.fgd");
    assert(fgdType !is null);
    assert(fgdType.name == "text/x-fgd");
    
    auto hlsprite = database.mimeTypeForData("IDSP\x02\x00\x00\x00");
    assert(hlsprite !is null);
    assert(hlsprite.name == "image/x-hlsprite");
    
    auto qsprite = database.mimeTypeForData("IDSP\x01\x00\x00\x00");
    assert(qsprite !is null);
    assert(qsprite.name == "image/x-qsprite");
    
    auto vpk = database.mimeTypeForFileName("pakdir.vpk");
    assert(vpk !is null);
    assert(vpk.name == "application/vnd.valve.vpk");
    
    //testng generic glob
    auto modelseq = database.mimeTypeForFileName("model01.mdl");
    assert(modelseq !is null);
    assert(modelseq.name == "application/x-hlmdl-sequence");
    modelseq = database.mimeTypeForFileName("model01.MDL");
    assert(modelseq !is null && modelseq.name == "application/x-hlmdl-sequence");
    
    assert(!database.mimeTypeForFileName("pak1.PAK"));
    assert(database.mimeTypeForFileName("pak1.pak"));
    
    //testing case-sensitive suffix
    assert(database.mimeTypeForFileName("my.shader"));
    assert(!database.mimeTypeForFileName("my.SHADER"));
}
