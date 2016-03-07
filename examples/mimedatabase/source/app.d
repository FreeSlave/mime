import std.stdio;
import std.getopt;
import std.array;
import std.typecons;

import mime.database;
import mime.paths;

void main(string[] args)
{
    string[] mimePaths;
    string[] filePaths;
    getopt(args, 
        "mimepath", "Set mime path to search files in.", &mimePaths
    );
    
    filePaths = args[1..$];
    
    version(OSX) {} else version(Posix) {
        if (!mimePaths.length) {
            mimePaths = mime.paths.mimePaths().array;
        }
    }
    if (!mimePaths.length) {
        stderr.writeln("No mime paths set");
        return;
    }
    
    auto database = new MimeDatabase(mimePaths);
    
    foreach(filePath; filePaths) {
        writefln("MIME type of '%s' according to", filePath);
        
        auto mimeType = rebindable(database.mimeTypeForFile(filePath, MimeDatabase.Match.globPatterns));
        writefln("\tglob patterns:\t%s", mimeType ? mimeType.name : "unknown");
        
        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.magicRules);
        writefln("\tmagic rules:\t%s", mimeType ? mimeType.name : "unknown");
        
        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.textFallback | MimeDatabase.Match.octetStreamFallback);
        writefln("\ttext or binary:\t%s", mimeType ? mimeType.name : "unknown");
        
        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.inodeFallback);
        writefln("\tinode fallback:\t%s", mimeType ? mimeType.name : "unknown");
    }
}
