import std.file;
import std.stdio;
import std.string;
import std.range;
import std.getopt;

import mime.cache;

void main(string[] args)
{
    string mimeCacheFile;
    string[] files;
    bool useMagic;
    getopt(args, 
           "mimecache", "Set mimecache file to use", &mimeCacheFile,
           "useMagic", "Use magic rules to get mime type alternatives", &useMagic,
          );
    
    files = args[1..$];
    
    if (!mimeCacheFile.length || !files.length) {
        writefln("Usage: %s --mimecache=<mimecache file> <files...> [--useMagic]", args[0]);
    } else {
        auto mimeCache = new MimeCache(mimeCacheFile);
        
        foreach(fileToCheck; files) {
            writefln("Alternatives for %s by file name:", fileToCheck);
            auto mimeTypes = mimeCache.findAllByFileName(fileToCheck);
            if (mimeTypes.empty) {
                writefln("No alternatives for %s", fileToCheck);
            }
            
            foreach(mimeType; mimeTypes) {
                auto parents = mimeCache.parents(mimeType.mimeType);
                writefln("%s: %s. Priority: %s. Parents: %s", fileToCheck, mimeType.mimeType, mimeType.weight, parents);
            }
            if (useMagic) {
                writefln("Alternatives for %s by file data:", fileToCheck);
                
                try {
                    void[] data = std.file.read(fileToCheck, 256);
                    foreach(mimeType; mimeCache.findAllByData(data)) {
                        auto parents = mimeCache.parents(mimeType.mimeType);
                        writefln("%s: %s. Priority: %s. Parents: %s", fileToCheck, mimeType.mimeType, mimeType.weight, parents);
                    }
                }
                catch (Exception e) {
                    stderr.writefln("Could not get MIME-type: %s", e.msg);
                }
            }
            
            writeln();
        }
    }
}
