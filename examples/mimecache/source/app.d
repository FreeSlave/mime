import std.file;
import std.stdio;
import std.string;
import std.range;

import mime.cache;

void main(string[] args)
{
    if (args.length < 3) {
        writefln("Usage: %s <mimecache file> <files...>", args[0]);
    } else {
        string mimeCacheFile = args[1];
        string[] files = args[2..$];
        
        auto mimeCache = new MimeCache(mimeCacheFile);
        
        foreach(fileToCheck; files) {
            auto mimeTypes = mimeCache.findAllByFileName(fileToCheck);
            if (mimeTypes.empty) {
                writefln("%s: could not determine MIME-type\n", fileToCheck);
            } else {
                writefln("Alternatives for %s:", fileToCheck);
                foreach(mimeType; mimeTypes) {
                    auto parents = mimeCache.parents(mimeType.mimeType);
                    
                    writefln("%s: %s. Priority: %s. Parents: %s", fileToCheck, mimeType.mimeType, mimeType.weight, parents);
                }
                writeln();
            }
        }
    }
}
