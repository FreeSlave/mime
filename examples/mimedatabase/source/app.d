import std.stdio;
import std.getopt;
import std.array;

import mime.database;
import mime.paths;

void main(string[] args)
{
    string[] mimePaths;
    string[] filePaths;
    bool printDatabase;
    getopt(args, 
        "mimepath", "Set mime path to search files in.", &mimePaths,
        "file", "Set file to determine its mime type.", &filePaths,
        "printDatabase", "Set to true to print short information on every mime type to stdout.", &printDatabase
    );
    
    version(Posix) {
        if (!mimePaths.length) {
            mimePaths = mime.paths.mimePaths().array;
        }
    }
    if (!mimePaths.length) {
        stderr.writeln("No mime paths set");
    }
    
    auto database = new MimeDatabase(mimePaths);
    
    if (printDatabase) {
        foreach(mimeType; database.byMimeType) {
            writeln("MimeType: ", mimeType.name);
            writeln("Aliases: ", mimeType.aliases);
            writeln("Parents: ", mimeType.parents);
            writeln("Icon: ", mimeType.icon);
            writeln("Generic icon: ", mimeType.genericIcon);
            writeln("Patterns: ", mimeType.patterns);
            writeln();
        }
    }
    
    foreach(filePath; filePaths) {
        auto mimeType = database.mimeTypeForFile(filePath);
        if (mimeType) {
            writefln("%s: %s\n", filePath, mimeType.name);
        } else {
            stderr.writefln("%s: could not determine MIME-type\n", filePath);
        }
        
    }
}
