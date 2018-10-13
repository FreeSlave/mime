/**
 * MIME store implemented around reading of various files in mime/ subfolder.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
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
    import std.array : empty;
    import std.exception;
    import std.file : isDir, FileException;
    import std.mmfile;
    import std.path;
    import std.range : retro;
    import std.range.interfaces : inputRangeObject;
    import std.range.primitives : isInputRange, ElementType;
    import std.stdio;
    import std.typecons;

    import mime.files.aliases;
    import mime.files.globs;
    import mime.files.icons;
    import mime.files.magic;
    import mime.files.namespaces;
    import mime.files.subclasses;
    import mime.files.types;
    import mime.files.treemagic;
}

public import mime.files.common;

private @trusted auto fileReader(string fileName) {
    return File(fileName, "r").byLineCopy();
}

/**
 * Implementation of $(D mime.store.IMimeStore) interface that uses various files from mime/ subfolder to read MIME types.
 */
final class FilesMimeStore : IMimeStore
{
    ///
    alias Tuple!(string, "fileName", Exception, "e") FileError;

    /**
     * Options to use when reading various shared MIME-info database files.
     */
    struct Options
    {
        enum : ubyte {
            skip = 0, ///Don't try to read file.
            read = 1, ///Try to read file. Give up on any error without throwing it.
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
        ubyte globs = optional;        ///Options for reading globs file. Used only if globs2 file could not be read.
        ubyte magic = skip;            ///Options for reading magic file.
        ubyte treemagic = skip;        ///Options for reading treemagic file.
    }

    private void handleError(Exception e, ubyte option, string fileName)
    {
        bool known;
        if (cast(MimeFileException)e !is null ||
            cast(MimeMagicFileException)e !is null ||
            cast(TreeMagicFileException)e !is null)
        {
            if (option & Options.throwParseError) {
                throw e;
            }
            known = true;
        }

        if (cast(ErrnoException)e !is null ||
            cast(FileException)e !is null)
        {
            if (option & Options.throwReadError) {
                throw e;
            }
            known = true;
        }

        if (!known) {
            throw e;
        }

        if (option & Options.saveErrors) {
            _errors ~= FileError(fileName, e);
        }
    }

    /**
     * Constructor based on MIME paths.
     * Params:
     *  mimePaths = Range of paths to base mime/ directories in order from more preferable to less preferable.
     *  options = Options for file reading and error reporting.
     * Throws:
     *  $(D mime.files.common.MimeFileException) if some info file has errors.
     *  $(D mime.files.magic.MimeMagicFileException) if magic file has errors.
     *  $(D mime.files.treemagic.TreeMagicFileException) if treemagic file has errors.
     *  $(B ErrnoException) or $(B FileException) if some important file does not exist or could not be read.
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
                } catch(Exception e) {
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
                        mimeType.addXMLnamespace(namespaceLine.namespaceUri, namespaceLine.localName);
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
                        if (t.deleteMagic) {
                            mimeType.clearMagic();
                        }
                        if (!t.magic.matches.empty) {
                            mimeType.addMagic(t.magic);
                        }
                    }
                    auto mmFile = new MmFile(magicPath);
                    magicFileReader(mmFile[], &sink);
                } catch(Exception e) {
                    handleError(e, options.magic, magicPath);
                }
            }

            if (options.treemagic & Options.read) {
                auto treemagicPath = buildPath(mimePath, "treemagic");
                try {
                    void treeSink(TreeMagicEntry t) {
                        auto mimeType = ensureMimeType(t.mimeType);
                        mimeType.addTreeMagic(t.magic);
                    }
                    auto mmFile = new MmFile(treemagicPath);
                    treeMagicFileReader(mmFile[], &treeSink);
                } catch(Exception e) {
                    handleError(e, options.treemagic, treemagicPath);
                }
            }
        }
    }

    unittest
    {
        auto mimePaths = ["test/errors"];
        const skipAll = Options(0,0,0,0,0,0,0,0,0,0);

        void fileTest(string name, T = MimeFileException)(ubyte opt = Options.required) {
            Options options = skipAll;
            mixin("options." ~ name ~ " = opt;");
            assertThrown!T(new FilesMimeStore(mimePaths, options));
        }

        fileTest!("types");
        fileTest!("aliases");
        fileTest!("subclasses");
        fileTest!("genericIcons");
        fileTest!("icons");
        fileTest!("XMLnamespaces");
        fileTest!("globs");
        fileTest!("globs2", ErrnoException);

        Options magic = skipAll;
        magic.magic = Options.required;
        assertThrown!MimeMagicFileException(new FilesMimeStore(mimePaths, magic));

        Options treemagic = skipAll;
        treemagic.treemagic = Options.required;
        assertThrown!TreeMagicFileException(new FilesMimeStore(mimePaths, treemagic));

        const opt = Options.allowFail | Options.saveErrors;
        const all = Options(opt, opt, opt, opt, opt, opt, opt, opt, opt, opt);
        auto store = new FilesMimeStore(mimePaths, all);
        assert(store.errors().length == 10);
    }

    ///
    InputRange!(const(MimeType)) byMimeType() {
        return inputRangeObject(_mimeTypes.byValue().map!(val => cast(const(MimeType))val));
    }

    ///
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
                mimeType.clearGlobs();
            } else {
                mimeType.addGlob(globLine.pattern, globLine.weight, globLine.caseSensitive);
            }
        }
    }

    MimeType[const(char)[]] _mimeTypes;
    FileError[] _errors;
}
