import std.stdio;
import mime.mimedatabase;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <mime.cache path>", args[0]);
    } else {
        auto database = new MimeDatabase(args[1]);
        
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
}
