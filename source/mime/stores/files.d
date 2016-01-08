module mime.stores.files;

import mime.store;
private {
    import std.algorithm : map;
    import std.exception : ErrnoException, collectException;
    import std.file : isDir;
    import std.path : buildPath;
    import std.range : retro, inputRangeObject;
    import std.stdio : File;
    
    import mime.files.aliases;
    import mime.files.globs;
    import mime.files.icons;
    import mime.files.magic;
    import mime.files.namespaces;
    import mime.files.subclasses;
}

private @trusted auto fileReader(string fileName) {
    return File(fileName, "r").byLine().map!(s => s.idup);
}

final class FilesMimeStore : IMimeStore
{
    @trusted this(Range)(Range mimePaths) if (is(ElementType!Range : string))
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
            try {
                setGlobs(globsFileReader(fileReader(globsPath)));
            } catch(ErrnoException e) {
                try {
                    globsPath = buildPath(mimePath, "globs");
                    setGlobs(globsFileReader(fileReader(globsPath)));
                } catch(ErrnoException e2) {
                    
                }
            }
        }
    }
    override InputRange!(const(MimeType)) byMimeType() {
        return inputRangeObject(_mimeTypes.byValue().map!(val => cast(const(MimeType))val));
    }
    override const(MimeType) mimeType(const char[] name) {
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
