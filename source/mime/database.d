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
import mime.utils;

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
        inodeFallback = 8, /// Provide inode/* fallback for files other than regular files
        textFallback = 16, /// Provide text/plain fallback if data seems to be textual.
        octetStreamFallback = 32 /// Provide application/octet-stream fallback if data seems to be binary.
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
    const(MimeType) mimeTypeForFileName(string fileName)
    {
        return findExistingAlternative(_detector.mimeTypesForFileName(fileName));
    }
    
    /**
     * Get MIME type for given data.
     */
    const(MimeType) mimeTypeForData(const(void)[] data)
    {
        return findExistingAlternative(_detector.mimeTypesForData(data));
    }
    
    /**
     * Get MIME type for file using methods describing in options.
     */
    const(MimeType) mimeTypeForFile(string fileName, const(void)[] data, Match options = Match.globPatterns|Match.magicRules|Match.octetStreamFallback|Match.textFallback)
    {
        return mimeTypeForFileImpl(fileName, data, options);
    }
    
    /**
     * Get MIME type for file using methods describing in options.
     * File contents will be read automatically if needed.
     */
    const(MimeType) mimeTypeForFile(string fileName, Match options = Match.globPatterns|Match.magicRules|Match.octetStreamFallback|Match.textFallback|Match.inodeFallback)
    {
        return mimeTypeForFileImpl(fileName, null, options);
    }
    
    private const(MimeType) mimeTypeForFileImpl(string fileName, const(void)[] data, Match options)
    {
        import std.file;
        import std.exception;
        
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
        
        if (data is null && (options & (Match.magicRules | Match.textFallback | Match.octetStreamFallback | Match.inodeFallback))) {
            version(Posix) {
                import core.sys.posix.sys.stat;
                import std.string : toStringz;
                
                stat_t statbuf;
                if (stat(toStringz(fileName), &statbuf) == 0) {
                    mode_t mode = statbuf.st_mode;
                    if (S_ISREG(mode)) {
                        //pass through to read data from file
                    } else if (options & Match.inodeFallback) {
                        return mimeType(inodeMimeType(mode));
                    } else {
                        return findExistingAlternative(mimeTypes);
                    }
                } else {
                    return findExistingAlternative(mimeTypes);
                }
            } else {
                bool ok;
                collectException(fileName.isFile, ok);
                if (ok) {
                    //pass through to read data from file
                } else if (options & Match.inodeFallback) {
                    collectException(fileName.isDir, ok);
                    if (ok) {
                        return mimeType("inode/directory");
                    } else {
                        return null;
                    }
                } else {
                    return findExistingAlternative(mimeTypes);
                }
            }
            
            // if need data
            if (options & (Match.magicRules | Match.textFallback | Match.octetStreamFallback )) {
                collectException(std.file.read(fileName, 256), data);
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
        
        return null;
    }
    
    private const(MimeType) findExistingAlternative(const(char[])[] conflicts)
    {
        foreach(name; conflicts) {
            auto type = mimeType(name);
            if (type !is null) {
                return type;
            }
        }
        return null;
    }
    
    /**
     * Get mime type by name or alias.
     * Returns: mime.type.MimeType object for given nameOrAlias, resolving alias if needed. Null if no mime type found.
     */
    const(MimeType) mimeType(const(char)[] nameOrAlias)
    {
        if (nameOrAlias.length == 0) {
            return null;
        }
        auto type = _store.mimeType(nameOrAlias);
        if (type is null) {
            auto resolved = _detector.resolveAlias(nameOrAlias);
            if (resolved.length) {
                auto resolvedType = _store.mimeType(resolved);
                if (resolvedType) {
                    return resolvedType;
                }
            }
        }
        return type;
    }
    
private:
    IMimeStore _store;
    IMimeDetector _detector;
}