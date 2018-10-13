/**
 * Detecting MIME type of file using MIME cache.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
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
 * Implementation of $(D mime.detector.IMimeDetector) interface using mmappable mime.cache files.
 */
final class MimeDetectorFromCache : IMimeDetector
{
    /**
     * Constructor based on existing MIME cache objects.
     * Params:
     *  mimeCaches = Range of mime.cache.MimeCache objects sorted in order of preference from the mort preferred to the least. All must be non-null.
     */
    this(Range)(Range mimeCaches) if (isInputRange!Range && is(ElementType!Range : const(MimeCache)))
    {
        _mimeCaches = mimeCaches.array;
    }

    /**
     * Constructor based on MIME paths. It automatically load mime.cache files from given paths.
     * Params:
     *  mimePaths = Range of paths to base mime/ directories in order from more preferable to less preferable.
     * Throws:
     *  FileException if some existing mime.cache could not be memory mapped.
     *  $(D mime.cache.MimeCacheException) if some existing mime.cache file is invalid.
     * See_Also: $(D mime.paths.mimePaths)
     */
    this(Range)(Range mimePaths) if (isInputRange!Range && is(ElementType!Range : string))
    {
        foreach(mimePath; mimePaths) {
            string path = buildPath(mimePath, "mime.cache");
            if (path.exists) {
                auto mimeCache = new MimeCache(path);
                _mimeCaches ~= mimeCache;
            }
        }
    }

    const(char)[] mimeTypeForFileName(const(char)[] fileName)
    {
        const(char)[] mimeType;
        uint weight;
        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByLiteral(fileName)) {
                if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..i])) {
                    continue;
                }
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
        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByGlob(fileName)) {
                if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..i])) {
                    continue;
                }
                if (mimeType.empty ||
                    weight < alternative.weight ||
                    (weight == alternative.weight && lastPatternLength < alternative.pattern.length))
                {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    lastPatternLength = alternative.pattern.length;
                }
            }
        }

        if (mimeType.length) {
            return mimeType;
        }

        size_t mimeCacheIndex;
        void exchangeAlternative(MimeTypeAlternativeByName alternative)
        {
            if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..mimeCacheIndex])) {
                return;
            }
            if (mimeType.empty ||
                weight < alternative.weight ||
                (weight == alternative.weight && lastPatternLength < alternative.pattern.length))
            {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                lastPatternLength = alternative.pattern.length;
            }
        }

        foreach(mimeCache; _mimeCaches) {
            mimeCache.findMimeTypesBySuffix(fileName, &exchangeAlternative);
            mimeCacheIndex++;
        }

        return mimeType;
    }

    const(char[])[] mimeTypesForFileName(const(char)[] fileName)
    {
        const(char)[][] conflicts;
        const(char)[] mimeType;
        uint weight;

        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByLiteral(fileName)) {
                if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..i])) {
                    continue;
                }
                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight &&
                    mimeType != alternative.mimeType &&
                    conflicts.find(alternative.mimeType).empty)
                {
                    conflicts ~= alternative.mimeType;
                }
            }
        }

        if (mimeType.length) {
            return mimeType ~ conflicts;
        }

        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByGlob(fileName)) {
                if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..i])) {
                    continue;
                }
                if (mimeType.empty || weight < alternative.weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight &&
                    mimeType != alternative.mimeType &&
                    conflicts.find(alternative.mimeType).empty)
                {
                    conflicts ~= alternative.mimeType;
                }
            }
        }

        if (mimeType.length) {
            return mimeType ~ conflicts;
        }

        size_t mimeCacheIndex;
        void exchangeAlternative(MimeTypeAlternativeByName alternative)
        {
            if (shouldDiscardGlob(alternative.mimeType, _mimeCaches[0..mimeCacheIndex])) {
                return;
            }
            if (mimeType.empty || weight < alternative.weight) {
                mimeType = alternative.mimeType;
                weight = alternative.weight;
                conflicts = null;
            } else if (weight == alternative.weight &&
                mimeType != alternative.mimeType &&
                conflicts.find(alternative.mimeType).empty)
            {
                conflicts ~= alternative.mimeType;
            }
        }

        foreach(mimeCache; _mimeCaches) {
            mimeCache.findMimeTypesBySuffix(fileName, &exchangeAlternative);
            mimeCacheIndex++;
        }

        if (mimeType.length) {
            return mimeType ~ conflicts;
        }

        return null;
    }

    private bool shouldDiscardGlob(const(char)[] mimeType, const(MimeCache)[] mimeCaches)
    {
        foreach(mimeCache; mimeCaches) {
            auto range = mimeCache
                .findMimeTypesByLiteral("__NOGLOBS__")
                .map!(alternative => alternative.mimeType)
                .find(mimeType);

            if (!range.empty) {
                return true;
            }
        }
        return false;
    }

    const(char)[] mimeTypeForData(const(void)[] data)
    {
        const(char)[] mimeType;
        uint weight;

        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByData(data)) {
                bool shouldDiscard = shouldDiscardMagic(alternative.mimeType, _mimeCaches[0..i]);
                if (shouldDiscard) {
                    continue;
                }

                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                }
                break;//checking only the first is enough because matches are sorted.
            }
        }

        return mimeType;
    }

    const(char[])[] mimeTypesForData(const(void)[] data)
    {
        const(char)[][] conflicts;
        const(char)[] mimeType;
        uint weight;

        foreach(i, mimeCache; _mimeCaches) {
            foreach(alternative; mimeCache.findMimeTypesByData(data)) {
                bool shouldDiscard = shouldDiscardMagic(alternative.mimeType, _mimeCaches[0..i]);
                if (shouldDiscard) {
                    continue;
                }

                if (mimeType.empty || alternative.weight > weight) {
                    mimeType = alternative.mimeType;
                    weight = alternative.weight;
                    conflicts = null;
                } else if (weight == alternative.weight &&
                    mimeType != alternative.mimeType &&
                    conflicts.find(alternative.mimeType).empty)
                {
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

    private bool shouldDiscardMagic(const(char)[] mimeType, const(MimeCache)[] mimeCaches)
    {
        foreach(mimeCache; mimeCaches) {
            if (!mimeCache.magicToDelete().equalRange(mimeType).empty) {
                return true;
            }
        }
        return false;
    }

    const(char)[] mimeTypeForNamespaceURI(const(char)[] namespaceURI)
    {
        foreach(mimeCache; _mimeCaches) {
            const(char)[] mimeType = mimeCache.findMimeTypeByNamespaceURI(namespaceURI);
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

    bool isSubclassOf(const(char)[] mimeType, const(char)[] parent)
    {
        foreach(mimeCache; _mimeCaches) {
            if (mimeCache.isSubclassOf(mimeType, parent)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get $(D mime.cache.MimeCache) objects.
     * Returns: All loaded $(D mime.cache.MimeCache) objects.
     */
    const(MimeCache[]) mimeCaches()
    {
        return _mimeCaches;
    }

private:
    const(MimeCache)[] _mimeCaches;
}
