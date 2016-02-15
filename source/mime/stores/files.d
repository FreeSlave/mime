/**
 * MIME store implemented around reading of various files in mime/ subfolder.
 * 
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

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

/**
 * Implementation of mime.store.IMimeStore interface that uses various files from mime/ subfolder to read MIME types.
 */
final class FilesMimeStore : IMimeStore
{
    /**
     * Constructor based on MIME paths.
     * Params:
     *  mimePaths = Range of paths to base mime directories where mime.cache is usually stored.
     * Throws:
     *  MimeFileException if some info file has errors.
     *  ErrnoException if some important file does not exist or could not be read.
     * See_Also: mime.paths.mimePaths
     */
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
    
    /**
     * See_Also: mime.store.IMimeStore.byMimeType
     */
    InputRange!(const(MimeType)) byMimeType() {
        return inputRangeObject(_mimeTypes.byValue().map!(val => cast(const(MimeType))val));
    }
    
    /**
     * See_Also: mime.store.IMimeStore.mimeType
     */
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
