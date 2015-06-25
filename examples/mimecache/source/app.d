import std.stdio;
import std.string;
import mime.mimecache;

void main(string[] args)
{
    if (args.length < 2) {
        writefln("Usage: %s <mimecache file>", args[0]);
    } else {
        string fileName = args[1];
        
        auto mimeCache = new MimeCache(fileName);
        
        foreach(namespaceEntry; mimeCache.namespaces) {
            writefln("Uri: %s, Local name: %s, MimeType: %s", namespaceEntry.namespaceUri, namespaceEntry.localName, namespaceEntry.mimeType);
        }
        
//         foreach(aliasEntry; mimeCache.aliases) {
//             writefln("%s => %s", aliasEntry.aliasName, aliasEntry.mimeType);
//         }
//         
//         foreach(parentEntry; mimeCache.parentEntries) {
//             writefln("%s: %s", parentEntry.mimeType, mimeCache.parents(parentEntry.mimeType));
//         }
//         
//         foreach(globEntry; mimeCache.globs) {
//             writefln("%s: %s. Weight: %s, cs: %s", globEntry.mimeType, globEntry.glob, globEntry.weight, globEntry.cs);
//         }
//         
//         foreach(iconEntry; mimeCache.icons) {
//             writefln("%s: %s", iconEntry.mimeType, iconEntry.iconName);
//         }
//         
//         foreach(iconEntry; mimeCache.genericIcons) {
//             writefln("%s: %s", iconEntry.mimeType, iconEntry.iconName);
//         }
        
//         foreach(literalEntry; mimeCache.literals) {
//             writefln("%s: %s. Weight: %s, cs: %s", literalEntry.mimeType, literalEntry.literal, literalEntry.weight, literalEntry.cs);
//         }
        
//         if (args.length > 2) {
//             writeln(mimeCache.findByFileName(args[2]));
//         }
    }
}
