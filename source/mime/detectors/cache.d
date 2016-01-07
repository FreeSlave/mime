module mime.detectors.cache;

import mime.detector;

private {
    import mime.cache;
    
    import std.algorithm;
    import std.array;
    import std.path;
    import std.range;
    import std.traits;
}

final class MimeDetectorFromCache : IMimeDetector
{
    @trusted this(Range)(Range mimeCaches) if (is(ElementType!Range : const(MimeCache)))
    {
        _mimeCaches = mimeCaches.array;
    }
    
    @trusted this(Range)(Range mimePaths) if (is(ElementType!Range : string))
    {
        foreach(mimePath; mimePaths) {
            try {
                string path = buildPath(mimePath, "mime.cache");
                auto mimeCache = new MimeCache(path);
                _mimeCaches = mimeCache;
            }
            catch(Exception e) {
                
            }
        }
    }
    
    const(char)[] mimeTypeNameForFileName(const(char)[] fileName)
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
    
    const(char)[][] mimeTypeNamesForFileName(const(char)[] fileName)
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
        
        return mimeType ~ conflicts;
    }
    
    const(char)[] mimeTypeNameForData(const(void)[] data)
    {
        const(char)[] mimeType;
        uint weight;
        
        foreach(mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByData(data)) {
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                }
            }
        }
        
        return mimeType;
    }
    
    const(char)[][] mimeTypeNamesForData(const(void)[] data)
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
                }
            }
        }
        
        return mimeType ~ conflicts;
    }
    
    const(char)[] mimeTypeNameForNamespaceUri(const(char)[] namespaceUri)
    {
        foreach(mimeCache; _mimeCaches) {
            const(char)[] mimeType = mimeCache.findMimeTypeByNamespaceUri(namespaceUri);
            if (mimeType.length) {
                return mimeType;
            }
        }
        return null;
    }
    
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
    
    const(MimeCache[]) mimeCaches()
    {
        return _mimeCaches;
    }
    
private:
    const(MimeCache)[] _mimeCaches;
}
