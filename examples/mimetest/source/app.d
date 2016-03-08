import std.array;
import std.exception;
import std.file;
import std.getopt;
import std.path;
import std.stdio;

import mime.cache;
import mime.detectors.cache;
import mime.stores.files;
import mime.database;
import mime.paths;

void main(string[] args)
{
    string[] mimePaths;
    getopt(args, 
        "mimepath", "Set mime path to search files in.", &mimePaths
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
            try {
                auto mimeCache = new MimeCache(cachePath);
                mimeCaches ~= mimeCache;
            } catch(MimeCacheException e) {
                stderr.writefln("%s: parse error: %s. Context: %s", cachePath, e.msg, e.context);
            } catch(Exception e) {
                stderr.writefln("%s: error: %s", cachePath, e.msg);
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
            stderr.writefln("%s", error.e.msg);
        }
    }
}
