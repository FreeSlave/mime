import std.algorithm;
import std.file;
import std.path;
import std.stdio;
import std.string;
import std.range;
import std.getopt;

import mime.cache;
import mime.detectors.cache;
import mime.paths;

int main(string[] args)
{
    string[] files;
    bool useMagic;
    getopt(args, 
           "useMagic", "Use magic rules to get mime type", &useMagic,
          );
    
    files = args[1..$];
    
    MimeCache[] mimeCaches;
    
    foreach (mimePath; mimePaths()) {
        string mimeCachePath = buildPath(mimePath, "mime.cache");
        if (mimeCachePath.exists) {
            try {
                auto mimeCache = new MimeCache(mimeCachePath);
                mimeCaches ~= mimeCache;
            }
            catch(Exception e) {
                stderr.writefln("Could not read cache from %s: %s", mimeCachePath, e.msg);
            }
        }
    }
    
    if (!mimeCaches.length) {
        stderr.writeln("Could not find any mime cache files");
        return 1;
    }
    
    writeln("Using mime cache files: ", mimeCaches.map!(cache => cache.fileName));
    
    auto mimeDetector = new MimeDetectorFromCache(mimeCaches);
    
    if (!files.length) {
        writeln("No files given");
    }
    
    foreach(fileToCheck; files) {
        auto mimeType = mimeDetector.mimeTypeNameForFileName(fileToCheck);
        auto alternatives = mimeDetector.mimeTypeNamesForFileName(fileToCheck);
        
        if (mimeType.length) {
            writefln("Mime type for %s: %s", fileToCheck, mimeType);
            writeln("Alternatives: ", alternatives);
        } else {
            writefln("Could not detect mime type for %s", fileToCheck);
        }
    }
    
    return 0;
}
