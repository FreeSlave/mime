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
    string[] mimeCachePaths;
    bool useMagic;
    getopt(args, 
           "useMagic", "Use magic rules to get mime type", &useMagic,
           "mimecache", "Use mime.cache files separated by comma, in this order of preference", &mimeCachePaths
          );
    
    mimeCachePaths = mimeCachePaths.length ? mimeCachePaths : mimePaths().map!(mimePath => buildPath(mimePath, "mime.cache")).array;
    files = args[1..$];
    
    MimeCache[] mimeCaches;
    
    foreach (mimeCachePath; mimeCachePaths) {
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
        if (useMagic) {
            auto data = std.file.read(fileToCheck, 64);
            auto mimeType = mimeDetector.mimeTypeForData(data);
            auto alternatives = mimeDetector.mimeTypesForData(data);
            
            if (mimeType.length) {
                writefln("%s: %s. Alternatives: %s", fileToCheck, mimeType, alternatives);
            } else {
                writefln("%s: could not detect mime type", fileToCheck);
            }
        } else {
            auto mimeType = mimeDetector.mimeTypeForFileName(fileToCheck);
            auto alternatives = mimeDetector.mimeTypesForFileName(fileToCheck);
            
            if (mimeType.length) {
                writefln("%s: %s. Alternatives: %s", fileToCheck, mimeType, alternatives);
            } else {
                writefln("%s: could not detect mime type", fileToCheck);
            }
        }
    }
    
    return 0;
}
