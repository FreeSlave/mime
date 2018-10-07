/+dub.sdl:
name "test"
dependency "mime" path="../"
+/

import std.array;
import std.exception;
import std.file;
import std.getopt;
import std.path;
import std.stdio;

import mime.cache;
import mime.detectors.cache;
import mime.stores.files;
import mime.stores.subtypexml;
import mime.database;
import mime.paths;
import mime.files.treemagic;

void main(string[] args)
{
    string[] mimePaths;
    bool verbose;
    getopt(args,
        "mimepath", "Set mime path to search files in.", &mimePaths,
        "verbose", "Print name of each examined file to standard output", &verbose
    );

    version(OSX) {} else version(Posix) {
        if (!mimePaths.length) {
            mimePaths = mime.paths.mimePaths().array;
        }
    }
    if (!mimePaths.length) {
        stderr.writeln("No mime paths set");
        return;
    }

    writefln("Using mime paths: %s", mimePaths);

    MimeCache[] mimeCaches;
    foreach(mimePath; mimePaths) {
        auto cachePath = buildPath(mimePath, "mime.cache");
        bool ok;
        collectException(cachePath.isFile, ok);
        if (ok) {
            if (verbose) {
                writeln("Reading mime cache file: ", cachePath);
            }
            try {
                auto mimeCache = new MimeCache(cachePath);
                mimeCaches ~= mimeCache;
            } catch(MimeCacheException e) {
                stderr.writefln("%s: parse error: %s. Context: %s", cachePath, e.msg, e.context);
            } catch(Exception e) {
                stderr.writefln("%s: error: %s", cachePath, e.msg);
            }
        }
        auto treemagicPath = buildPath(mimePath, "treemagic");
        collectException(treemagicPath.isFile, ok);
        if (ok) {
            if (verbose) {
                writeln("Reading treemagic file: ", treemagicPath);
            }
            try {
                auto data = assumeUnique(read(treemagicPath));
                treeMagicFileReader(data, (TreeMagicEntry t) {});
            } catch(Exception e) {
                stderr.writefln("%s: error: %s", treemagicPath, e.msg);
            }
        }
    }

    alias FilesMimeStore.Options FOptions;
    FOptions foptions;
    ubyte opt = FOptions.read | FOptions.saveErrors;

    foptions.types = opt;
    foptions.aliases = opt;
    foptions.subclasses = opt;
    foptions.icons = opt;
    foptions.genericIcons = opt;
    foptions.XMLnamespaces = opt;
    foptions.globs2 = opt;
    foptions.globs = opt;
    foptions.magic = opt;

    auto mimeStore = new FilesMimeStore(mimePaths, foptions);
    foreach(error; mimeStore.errors) {
        auto me = cast(MimeFileException)error.e;
        if (me) {
            stderr.writefln("%s: parse error: %s. Bad line: %s", error.fileName, me.msg, me.lineString);
        } else {
            stderr.writefln("%s: %s", error.fileName, error.e.msg);
        }
    }

    auto xmlStore = new MediaSubtypeXmlStore(mimePaths);
    foreach(mimeType; xmlStore.byMimeType()) {}
}
