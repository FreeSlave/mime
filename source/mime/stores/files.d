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
    import std.typecons;
    
    import mime.files.aliases;
    import mime.files.globs;
    import mime.files.icons;
    import mime.files.magic;
    import mime.files.namespaces;
    import mime.files.subclasses;
    import mime.files.types;
}

public import mime.files.common;

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
 * Implementation of $(D mime.store.IMimeStore) interface that uses various files from mime/ subfolder to read MIME types.
 */
final class FilesMimeStore : IMimeStore
{
    alias Tuple!(string, "fileName", Exception, "e") FileError;
    
    /**
     * Options to use when reading various shared MIME-info database files.
     */
    struct Options
    {
        enum : ubyte {
            skip = 0, ///Don't try to read file.
            read = 1, ///Try do read file.
            throwReadError = 2, ///Throw on file reading error.
            throwParseError = 4, ///Throw on file parsing error.
            saveErrors = 8, ///Save non-thrown errors to retrieve later via errors method.
            
            optional = read | throwParseError,   ///Read file if it's readable. Throw only on malformed contents.
            required = read | throwReadError | throwParseError,   ///Always try to read file, throw on any error.
            allowFail = read,  ///Don't throw if file can't be read or has invalid contents.    
        }
        
        ubyte types = optional;        ///Options for reading types file.
        ubyte aliases = optional;      ///Options for reading aliases file.
        ubyte subclasses = optional;   ///Options for reading subclasses file.
        ubyte icons = optional;        ///Options for reading icons file.
        ubyte genericIcons = optional; ///Options for reading generic-icons file.
        ubyte XMLnamespaces = optional;///Options for reading XMLnamespaces file.
        ubyte globs2 = optional;       ///Options for reading globs2 file.
        ubyte globs = optional;        ///Options for reading globs file. Used only if globs2 file could not or was not read.
        ubyte magic = optional;        ///Options for reading magic file.
    }
    
    private void handleError(Exception e, ubyte option, string fileName)
    {
        auto me = cast(MimeFileException)e;
        auto mme = cast(MimeMagicFileException)e;
        if ((me !is null || mme !is null) && option & Options.throwParseError) {
            if (me) {
                throw me;
            } else {
                throw mme;
            }
        }
        
        auto ee = cast(ErrnoException)e;
        auto fe = cast(FileException)e;
        if ((ee !is null || fe !is null) && option & Options.throwReadError) {
            if (ee) {
                throw ee;
            } else {
                throw fe;
            }   
        }
        
        if (ee is null && fe is null && me is null && mme is null) {
            throw e;
        }
        
        if (option & Options.saveErrors) {
            _errors ~= FileError(fileName, e);
        }
    }
    
    /**
     * Constructor based on MIME paths.
     * Params:
     *  mimePaths = Range of paths to base mime directories where mime.cache is usually stored.
     *  options = Options for file reading and error reporting.
     * Throws:
     *  $(D MimeFileException) if some info file has errors.
     *  $(D MimeMagicFileException) if magic file has errors.
     *  ErrnoException if some important file does not exist or could not be read.
     * See_Also: $(D mime.paths.mimePaths)
     */
    this(Range)(Range mimePaths, Options options = Options.init) if (isInputRange!Range && is(ElementType!Range : string))
    {
        foreach(mimePath; mimePaths.retro) {
            bool dirExists;
            collectException(mimePath.isDir, dirExists);
            if (!dirExists) {
                continue;
            }
            
            if (options.types & Options.read) {
                auto typesPath = buildPath(mimePath, "types");
                try {
                    foreach(line; typesFileReader(fileReader(typesPath))) {
                        ensureMimeType(line);
                    }
                } catch(Exception e) {
                    handleError(e, options.types, typesPath);
                }
            }
            
            if (options.aliases & Options.read) {
                auto aliasesPath = buildPath(mimePath, "aliases");
                try {
                    auto aliases = aliasesFileReader(fileReader(aliasesPath));
                    foreach(aliasLine; aliases) {
                        auto mimeType = ensureMimeType(aliasLine.mimeType);
                        mimeType.addAlias(aliasLine.aliasName);
                    }
                } catch(Exception e) {
                    handleError(e, options.aliases, aliasesPath);
                }
            }
            
            if (options.subclasses & Options.read) {
                auto subclassesPath = buildPath(mimePath, "subclasses");
                try {
                    auto subclasses = subclassesFileReader(fileReader(subclassesPath));
                    foreach(subclassLine; subclasses) {
                        auto mimeType = ensureMimeType(subclassLine.mimeType);
                        mimeType.addParent(subclassLine.parent);
                    }
                } catch(Exception e) {
                    handleError(e, options.subclasses, subclassesPath);
                }
            }
            
            if (options.icons & Options.read) {
                auto iconsPath = buildPath(mimePath, "icons");
                try {
                    auto icons = iconsFileReader(fileReader(iconsPath));
                    foreach(iconLine; icons) {
                        auto mimeType = ensureMimeType(iconLine.mimeType);
                        mimeType.icon = iconLine.iconName;
                    }
                } catch(ErrnoException e) {
                    handleError(e, options.icons, iconsPath);
                }
            }
            
            if (options.genericIcons & Options.read) {
                auto genericIconsPath = buildPath(mimePath, "generic-icons");
                try {
                    auto icons = iconsFileReader(fileReader(genericIconsPath));
                    foreach(iconLine; icons) {
                        auto mimeType = ensureMimeType(iconLine.mimeType);
                        mimeType.genericIcon = iconLine.iconName;
                    }
                } catch(Exception e) {
                    handleError(e, options.genericIcons, genericIconsPath);
                }
            }
            
            if (options.XMLnamespaces & Options.read) {
                auto namespacesPath = buildPath(mimePath, "XMLnamespaces");
                try {
                    auto namespaces = namespacesFileReader(fileReader(namespacesPath));
                    foreach(namespaceLine; namespaces) {
                        auto mimeType = ensureMimeType(namespaceLine.mimeType);
                        mimeType.namespaceUri = namespaceLine.namespaceUri;
                    }
                } catch(Exception e) {
                    handleError(e, options.XMLnamespaces, namespacesPath);
                }
            }
            
            bool shouldReadGlobs = false;
            if (options.globs2 & Options.read) {
                auto globs2Path = buildPath(mimePath, "globs2");
                try {
                    setGlobs(globs2FileReader(fileReader(globs2Path)));
                } catch(Exception e) {
                    handleError(e, options.globs2, globs2Path);
                    shouldReadGlobs = true;
                }
            } else {
                shouldReadGlobs = true;
            }
            
            if (shouldReadGlobs && (options.globs & Options.read)) {
                auto globsPath = buildPath(mimePath, "globs");
                try {
                    setGlobs(globsFileReader(fileReader(globsPath)));
                } catch(Exception e) {
                    handleError(e, options.globs, globsPath);
                }
            }
            
            if (options.magic & Options.read) {
                auto magicPath = buildPath(mimePath, "magic");
                try {
                    void sink(MagicEntry t) {
                        auto mimeType = ensureMimeType(t.mimeType);
                        if (t.magic.shouldDeleteMagic()) {
                            mimeType.clearMagic();
                        } else {
                            mimeType.addMagic(t.magic);
                        }
                    }
                    magicFileReader(assumeUnique(std.file.read(magicPath)), &sink);
                } catch(Exception e) {
                    handleError(e, options.magic, magicPath);
                }
            }
        }
    }
    
    /**
     * See_Also: $(D mime.store.IMimeStore.byMimeType)
     */
    InputRange!(const(MimeType)) byMimeType() {
        return inputRangeObject(_mimeTypes.byValue().map!(val => cast(const(MimeType))val));
    }
    
    /**
     * See_Also: $(D mime.store.IMimeStore.mimeType)
     */
    Rebindable!(const(MimeType)) mimeType(const char[] name) {
        return rebindable(mimeTypeImpl(name));
    }
    
    private final const(MimeType) mimeTypeImpl(const char[] name) {
        MimeType* pmimeType = name in _mimeTypes;
        if (pmimeType) {
            return *pmimeType;
        } else {
            return null;
        }
    }
    
    /**
     * Get errors that were told to not throw but to be saved during parsing.
     */
    const(FileError)[] errors() const {
        return _errors;
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
    FileError[] _errors;
}
