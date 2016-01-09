module mime.stores.files;

import mime.common;
import mime.store;

private {
    import std.algorithm : map;
    import std.exception;
    import std.file;
    import std.path;
    import std.range;
    import std.stdio;
    
    import mime.files.aliases;
    import mime.files.globs;
    import mime.files.icons;
    import mime.files.magic;
    import mime.files.namespaces;
    import mime.files.subclasses;
}

/**
 * Check is pattern is __NOGLOBS__. This means glob patterns from less preferable MIME paths should be ignored.
 */
@nogc @safe bool isNoGlobs(string pattern) pure nothrow {
    return pattern == "__NOGLOBS__";
}

private @trusted auto fileReader(string fileName) {
    static if( __VERSION__ < 2067 ) {
        return File(fileName, "r").byLine().map!(s => s.idup);
    } else {
        return File(fileName, "r").byLineCopy();
    }
}

private bool fileExists(string fileName) {
    bool ok;
    collectException(fileName.isFile, ok);
    return ok;
}

final class FilesMimeStore : IMimeStore
{
    @trusted this(Range)(Range mimePaths) if (isInputRange!Range && is(ElementType!Range : string))
    {
        foreach(mimePath; mimePaths.retro) {
            bool dirExists;
            collectException(mimePath.isDir, dirExists);
            if (!dirExists) {
                continue;
            }
            
            auto typesPath = buildPath(mimePath, "types");
            try {
                foreach(line; File(typesPath, "r").byLine()) {
                    if (line.length) {
                        ensureMimeType(line);
                    }
                }
            } catch(ErrnoException e) {
                
            }
            
            auto aliasesPath = buildPath(mimePath, "aliases");
            try {
                auto aliases = aliasesFileReader(fileReader(aliasesPath));
                foreach(aliasLine; aliases) {
                    auto mimeType = ensureMimeType(aliasLine.mimeType);
                    mimeType.addAlias(aliasLine.aliasName);
                }
            } catch(ErrnoException e) {
                
            }
            
            auto subclassesPath = buildPath(mimePath, "subclasses");
            try {
                auto subclasses = subclassesFileReader(fileReader(subclassesPath));
                foreach(subclassLine; subclasses) {
                    auto mimeType = ensureMimeType(subclassLine.mimeType);
                    mimeType.addParent(subclassLine.parent);
                }
            } catch(ErrnoException e) {
                
            }
            
            auto iconsPath = buildPath(mimePath, "icons");
            try {
                auto icons = iconsFileReader(fileReader(iconsPath));
                foreach(iconLine; icons) {
                    auto mimeType = ensureMimeType(iconLine.mimeType);
                    mimeType.icon = iconLine.iconName;
                }
            } catch(ErrnoException e) {
                
            }
            
            auto genericIconsPath = buildPath(mimePath, "generic-icons");
            try {
                auto icons = iconsFileReader(fileReader(genericIconsPath));
                foreach(iconLine; icons) {
                    auto mimeType = ensureMimeType(iconLine.mimeType);
                    mimeType.genericIcon = iconLine.iconName;
                }
            } catch(ErrnoException e) {
                
            }
            
            auto namespacesPath = buildPath(mimePath, "XMLnamespaces");
            try {
                auto namespaces = namespacesFileReader(fileReader(namespacesPath));
                foreach(namespaceLine; namespaces) {
                    auto mimeType = ensureMimeType(namespaceLine.mimeType);
                    mimeType.localName = namespaceLine.localName;
                    mimeType.namespaceUri = namespaceLine.namespaceUri;
                }
            } catch(ErrnoException e) {
                
            }
            
            auto globsPath = buildPath(mimePath, "globs2");
            if (globsPath.fileExists) {
                setGlobs(globsFileReader(fileReader(globsPath)));
            } else {
                globsPath = buildPath(mimePath, "globs");
                setGlobs(globsFileReader(fileReader(globsPath)));
            }
            
            auto magicPath = buildPath(mimePath, "magic");
            void sink(MagicEntry t) {
                auto mimeType = ensureMimeType(t.mimeType);
                if (t.magic.shouldDeleteMagic()) {
                    mimeType.clearMagic();
                } else {
                    mimeType.addMagic(t.magic);
                }
            }
            magicFileReader(assumeUnique(std.file.read(magicPath)), &sink);
        }
    }
    InputRange!(const(MimeType)) byMimeType() {
        return inputRangeObject(_mimeTypes.byValue().map!(val => cast(const(MimeType))val));
    }
    const(MimeType) mimeType(const char[] name) {
        MimeType* pmimeType = name in _mimeTypes;
        if (pmimeType) {
            return *pmimeType;
        } else {
            return null;
        }
    }
    
private:
    @trusted MimeType ensureMimeType(const(char)[] name) {
        MimeType* pmimeType = name in _mimeTypes;
        if (pmimeType) {
            return *pmimeType;
        } else {
            string mimeName = name.idup;
            auto mimeType = new MimeType(mimeName);
            mimeType.icon = defaultIconName(mimeName);
            mimeType.genericIcon = defaultGenericIconName(mimeName);
            _mimeTypes[mimeName] = mimeType;
            return mimeType;
        }
    }
    
    @trusted void setGlobs(Range)(Range globs) {
        foreach(globLine; globs) {
            if (!globLine.pattern.length) {
                continue;
            }
            auto mimeType = ensureMimeType(globLine.mimeType);
            
            if (globLine.pattern.isNoGlobs()) {
                mimeType.clearPatterns();
            } else {
                mimeType.addPattern(globLine.pattern, globLine.weight, globLine.caseSensitive);
            }
        }
    }
    
    MimeType[const(char)[]] _mimeTypes;
}
