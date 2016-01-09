/**
 * Detecting MIME type of file using MIME cache.
 * 
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.detectors.cache;

import mime.detector;

private {
    import mime.cache;
    
    import std.algorithm;
    import std.array;
    import std.file;
    import std.path;
    import std.range;
    import std.traits;
}

/**
 * Implementation of mime.detector.IMimeDetector interface using mmappable mime.cache files.
 */
final class MimeDetectorFromCache : IMimeDetector
{
    /**
     * Constructor based on existing MIME cache objects.
     * Params:
     *  mimeCaches = Range of mime.cache.MimeCache objects sorted in order of preference from the mort preferred to the least. All must be non-null.
     */
    @trusted this(Range)(Range mimeCaches) if (is(ElementType!Range : const(MimeCache)))
    {
        _mimeCaches = mimeCaches.array;
    }
    
    /**
     * Constructor based on MIME paths. It automatically load mime.cache files from given paths.
     * Params:
     *  mimePaths = Range of paths to base mime directories where mime.cache is usually stored.
     * Throws:
     *  FileException if some existing mime.cache could not be memory mapped.
     *  mime.cache.MimeCacheException if some existing mime.cache file is invalid.
     * See_Also: mime.paths.mimePaths
     */
    @trusted this(Range)(Range mimePaths) if (is(ElementType!Range : string))
    {
        foreach(mimePath; mimePaths) {
            string path = buildPath(mimePath, "mime.cache");
            if (path.exists) {
                auto mimeCache = new MimeCache(path);
                _mimeCaches ~= mimeCache;
            }
        }
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.mimeTypeNameForFileName
     */
    const(char)[] mimeTypeForFileName(const(char)[] fileName)
    {
        const(char)[] mimeType;
        uint weight;
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByLiteral(fileName)) {
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                }
            }
        }
        if (mimeType.length) {
            return mimeType;
        }
        
        size_t lastPatternLength;
        void exchangeAlternative(MimeTypeAlternativeByName alternative)
        {
            if (mimeType.empty || weight < alternative.weight || (weight == alternative.weight && lastPatternLength < alternative.pattern.length)) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                lastPatternLength = alternative.pattern.length;
            }
        }
        
        foreach(mimeCache; _mimeCaches) {
            mimeCache.findMimeTypesBySuffix(fileName, &exchangeAlternative);
        }
        
        if (mimeType.length) {
            return mimeType;
        }
        
        lastPatternLength = 0;
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByGlob(fileName)) {
                if (mimeType.empty || weight < alternative.weight || (weight == alternative.weight && lastPatternLength < alternative.pattern.length)) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    lastPatternLength = alternative.pattern.length;
                }
            }
        }
        
        return mimeType;
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.mimeTypeNamesForFileName
     */
    const(char[])[] mimeTypesForFileName(const(char)[] fileName)
    {
        const(char)[][] conflicts;
        const(char)[] mimeType;
        uint weight;
        
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByLiteral(fileName)) {
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight && mimeType != alternative.mimeType && conflicts.find(alternative.mimeType).empty) {
                    conflicts ~= alternative.mimeType;
                }
            }
        }
        
        if (mimeType.length) {
            return mimeType ~ conflicts;
        }
        
        void exchangeAlternative(MimeTypeAlternativeByName alternative)
        {
            if (mimeType.empty || weight < alternative.weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                conflicts = null;
            } else if (weight == alternative.weight && mimeType != alternative.mimeType && conflicts.find(alternative.mimeType).empty) {
                conflicts ~= alternative.mimeType;
            }
        }
        
        foreach(mimeCache; _mimeCaches) {
            mimeCache.findMimeTypesBySuffix(fileName, &exchangeAlternative);
        }
        
        if (mimeType.length) {
            return mimeType ~ conflicts;
        }
        
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByGlob(fileName)) {
                if (mimeType.empty || weight < alternative.weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight && mimeType != alternative.mimeType && conflicts.find(alternative.mimeType).empty) {
                    conflicts ~= alternative.mimeType;
                }
            }
        }
        
        if (mimeType.length) {
            return mimeType ~ conflicts;
        }
        return null;
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.mimeTypeNameForData
     */
    const(char)[] mimeTypeForData(const(void)[] data)
    {
        const(char)[] mimeType;
        uint weight;
        
        foreach(mimeCache; _mimeCaches) {
            auto matches = mimeCache.findMimeTypesByData(data);
            if (!matches.empty) {
                auto alternative = matches.front; //checking only the first is enough because matches are sorted.
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                }
            }
        }
        
        return mimeType;
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.mimeTypeNamesForData
     */
    const(char[])[] mimeTypesForData(const(void)[] data)
    {
        const(char)[][] conflicts;
        const(char)[] mimeType;
        uint weight;
        
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByData(data)) {
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight && mimeType != alternative.mimeType && conflicts.find(alternative.mimeType).empty) {
                    conflicts ~= alternative.mimeType;
                } else if (weight > alternative.weight) {
                    break; //stop since there're no alternatives with equal or better weight left.
                }
            }
        }
        
        if (mimeType.length) {
            return mimeType ~ conflicts;
        }
        return null;
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.mimeTypeNameForNamespaceUri
     */
    const(char)[] mimeTypeForNamespaceUri(const(char)[] namespaceUri)
    {
        foreach(mimeCache; _mimeCaches) {
            const(char)[] mimeType = mimeCache.findMimeTypeByNamespaceUri(namespaceUri);
            if (mimeType.length) {
                return mimeType;
            }
        }
        return null;
    }
    
    /**
     * See_Also: mime.detector.IMimeDetector.resolveAlias
     */
    const(char)[] resolveAlias(const(char)[] aliasName)
    {
        foreach(mimeCache; _mimeCaches) {
            const(char)[] mimeType = mimeCache.resolveAlias(aliasName);
            if (mimeType.length) {
                return mimeType;
            }
        }
        return null;
    }
    
    /**
     * Get used MimeCache objects.
     * Returns: All loaded mime.cache.MimeCache objects.
     */
    const(MimeCache[]) mimeCaches()
    {
        return _mimeCaches;
    }
    
private:
    const(MimeCache)[] _mimeCaches;
}
