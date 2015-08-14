/**
 * Class for reading MIME database.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov 2015
 */

module mime.mimedatabase;

import mime.type;
import mime.common;
import mime.cache;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.exception;
    import std.file;
    import std.path;
    import std.range;
    import std.string;
    import std.stdio;
    import std.system;
    import std.traits;
    import std.typecons;
    import std.uni;
    
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
    @trusted this(in string[] mimePaths) {
        
        if (mimePaths.empty) {
            throw new Exception("no mime paths given");
        }
        
        foreach(mimePath; mimePaths.retro) {
            bool dirExists;
            collectException(mimePath.isDir, dirExists);
            if (!dirExists) {
                continue;
            }
            
            auto typesPath = buildPath(mimePath, "types");
            try {
                foreach(line; File(typesPath, "r").byLine()) {
                    ensureMimeType(line);
                }
            } catch(ErrnoException e) {
                
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
            
            try {
                string mimeCachePath = buildPath(mimePath, "mime.cache");
                _caches ~= new MimeCache(cast(immutable(void)[])std.file.read(mimeCachePath), mimeCachePath);
            } catch (FileException e) {
                
            }
        }
    }
    
    @nogc @safe const(MimeType)* mimeType(const(char)[] name) nothrow const {
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
        foreach(mimeCache; byMimeCache()) {
            auto mimeTypeName = mimeCache.findOneByFileName(fileName);
            if (mimeTypeName.length) {
                auto type = mimeType(mimeTypeName);
                if (type) {
                    return type;
                }
            }
        }
        return null;
    }
    
    const(MimeType)* mimeTypeForData(const(void)[] data) const {
        foreach(mimeCache; byMimeCache()) {
            auto mimeTypeName = mimeCache.findOneByData(data);
            if (mimeTypeName.length) {
                auto type = mimeType(mimeTypeName);
                if (type) {
                    return type;
                }
            }
        }
        
        auto textPlain = mimeType("text/plain");
        auto octetStream = mimeType("application/octet-stream");
        if (textPlain) {
            auto str = cast(const(char)[])data;
            foreach(dchar c; str.byCodePoint().take(256)) {
                if (!isGraphical(c) && !isControl(c)) {
                    return octetStream;
                }
            }
            return textPlain;
        }
        
        return null;
    }
    
    const(MimeType)* mimeTypeForFile(string name) const {
        auto type = mimeTypeForFileName(name);
        if (type) {
            return type;
        } else {
            version(Posix) {
                import core.sys.posix.sys.stat;
                stat_t statbuf;
                if (stat(toStringz(name), &statbuf) == 0) {
                    mode_t mode = statbuf.st_mode;
                    if (S_ISREG(mode)) {
                        //skip
                    } else if (S_ISDIR(mode)) {
                        return mimeType("inode/directory");
                    } else if (S_ISCHR(mode)) {
                        return mimeType("inode/chardevice");
                    } else if (S_ISBLK(mode)) {
                        return mimeType("inode/blockdevice");
                    } else if (S_ISFIFO(mode)) {
                        return mimeType("inode/fifo");
                    }
                }
            } else {
                bool itsDir;
                collectException(name.isDir, itsDir);
                if (itsDir) {
                    return mimeType("inode/directory");
                }
            }
            void[] data;
            collectException(std.file.read(name, 256), data);
            if (data.length) {
                return mimeTypeForData(data);
            }
        }
        return null;
    }
    
    @nogc @trusted auto byMimeType() nothrow const {
        return _mimeTypes.byValue();
    }
    
    @nogc @trusted auto byMimeCache() nothrow const {
        return _caches.retro;
    }
    
private:
    
    @trusted void setGlobs(Range)(Range globs) {
        foreach(globLine; globs) {
            if (globLine.pattern.empty) {
                continue;
            }
            auto mimeType = ensureMimeType(globLine.mimeType);
            
            if (globLine.pattern.isNoGlobs()) {
                mimeType.clearPatterns();
            } else {
                mimeType.addPattern(globLine.pattern, globLine.weight, globLine.caseSensitive);
            
                if (globLine.pattern.startsWith("*.") && globLine.pattern.length > 2 && !globLine.pattern[2..$].hasGlobMatchSymbols) {
                    addGlob(globLine, _suffixes, globLine.pattern[1..$]);
                } else if (globLine.pattern.hasGlobMatchSymbols) {
                    addGlob(globLine, _otherGlobs, globLine.pattern);
                } else {
                    addGlob(globLine, _literals, globLine.pattern);
                }
            }
        }
    }
    
    @trusted void addGlob(const GlobLine globLine, ref GlobLine[][string] globs, string key) {
        auto globLinesPtr = key in globs;
        if (globLinesPtr) {
            *globLinesPtr ~= globLine;
        } else {
            globs[key] = [globLine];
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
    MimeCache[] _caches;
    string[string] _aliases;
    
    GlobLine[][string] _suffixes;
    GlobLine[][string] _literals;
    GlobLine[][string] _otherGlobs;
}

