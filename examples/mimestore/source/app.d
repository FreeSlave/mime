import std.stdio;

import mime.stores.files;
import mime.paths;

void main(string[] args)
{
    //auto fileName = args.length > 1 ? args[1] : "/home/freeslave/.local/share/mime";
    
    auto store = new FilesMimeStore(mimePaths());
    foreach(mimeType; store.byMimeType())
    {
        writefln("Name: %s. Icon: %s. Generic-Icon: %s. Aliases: %s. Parents: %s. Patterns: %s", mimeType.name, mimeType.icon, mimeType.genericIcon, mimeType.aliases, mimeType.parents, mimeType.patterns);
    }
}
