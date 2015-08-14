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
            auto mimeType = mimeCache.findOneByFile(fileToCheck, read(fileToCheck, 256));
            if (mimeType.empty) {
                writefln("%s: could not determine MIME-type\n", fileToCheck);
            } else {
                auto icon = mimeCache.findIcon(mimeType);
                auto genericIcon = mimeCache.findGenericIcon(mimeType);
                auto parents = mimeCache.parents(mimeType);
                
                writefln("%s: %s. Parents: %s", fileToCheck, mimeType, parents);
                writeln();
            }
        }
    }
}
