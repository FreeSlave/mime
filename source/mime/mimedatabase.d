module mime.mimedatabase;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.exception;
    import std.file;
    import std.path;
    import std.range;
    import std.stdio;
    import std.system;
    import std.traits;
    import std.typecons;
    
    import mime.common;
    
    import mime.database.aliases;
    import mime.database.globs;
    import mime.database.icons;
    import mime.database.magic;
    import mime.database.namespaces;
    import mime.database.subclasses;
}

import mime.mimetype;

private @trusted auto fileReader(string fileName) {
    return File(fileName, "r").byLine().map!(s => s.idup);
}

private @nogc @trusted bool hasGlobMatchSymbols(string s) nothrow pure {
    static @nogc @safe bool isGlobMatchSymbol(char c) nothrow pure {
        return c == '*' || c == '?' || c == '[';
    }
    
    for (size_t i=0; i<s.length; ++i) {
        if (isGlobMatchSymbol(s[i])) {
            return true;
        }
    }
    return false;
}

class MimeDatabase
{
    this(string mimePath) {
        
        if (mimePath.empty) {
            throw new Exception("empty path given");
        }
        
        auto aliasesPath = buildPath(mimePath, "aliases");
        try {
            auto aliases = aliasesFileReader(fileReader(aliasesPath));
            foreach(aliasLine; aliases) {
                auto mimeType = ensureMimeType(aliasLine.mimeType);
                mimeType.addAlias(aliasLine.aliasName);
                _aliases[aliasLine.aliasName] = aliasLine.mimeType;
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
            } catch(ErrnoException e2) {
                setGlobs(globsFileReader(fileReader(globsPath)));
            }
        }
    }
    
    @nogc @safe const(MimeType)* mimeType(string name) nothrow const {
        auto mType = name in _mimeTypes;
        if (mType) {
            return mType;
        } else {
            auto mimeName = name in _aliases;
            if (mimeName) {
                return *mimeName in _mimeTypes;
            }
        }
        return null;
    }
    
    const(MimeType)* mimeTypeForFileName(string fileName) const {
        return null;
    }
    
    const(MimeType)* mimeTypeForData(const(void)[] data) const {
        return null;
    }
    
    @nogc @trusted auto byMimeType() nothrow const {
        return _mimeTypes.byValue();
    }
    
private:
    
    void setGlobs(Range)(Range globs) {
        foreach(globLine; globs) {
            if (globLine.pattern.empty) {
                continue;
            }
            auto mimeType = ensureMimeType(globLine.mimeType);
            mimeType.addPattern(globLine.pattern, globLine.weight, globLine.caseSensitive);
            
            if (globLine.pattern.startsWith("*") && !globLine.pattern[1..$].hasGlobMatchSymbols) {
                addGlob(globLine, _suffixes);
            } else if (globLine.pattern.hasGlobMatchSymbols) {
                addGlob(globLine, _otherGlobs);
            } else {
                addGlob(globLine, _literals);
            }
        }
    }
    
    @trusted void addGlob(const GlobLine globLine, ref GlobLine[][string] globs) {
        auto globLinesPtr = globLine.pattern in globs;
        if (globLinesPtr) {
            auto globLines = *globLinesPtr;
            globLines ~= globLine;
        } else {
            globs[globLine.pattern] = [globLine];
        }
    }
    
    @trusted MimeType* ensureMimeType(const(char)[] name) nothrow {
        MimeType* mimeType = name in _mimeTypes;
        if (mimeType) {
            return mimeType;
        } else {
            string mimeName = name.idup;
            _mimeTypes[mimeName] = MimeType(mimeName);
            return mimeName in _mimeTypes;
        }
    }
    
    MimeType[const(char)[]] _mimeTypes;
    string[string] _aliases;
    
    GlobLine[][string] _suffixes;
    GlobLine[][string] _literals;
    GlobLine[][string] _otherGlobs;
}

