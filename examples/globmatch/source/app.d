import std.stdio;
import mime.database.globs;

void main(string[] args)
{
    if (args.length < 2) {
        writefln("Usage: %s <globs2 file>", args[0]);
    } else {
        foreach(GlobCache glob; globsFileReader(args[1])) {
            writefln("%s:%s:%s:%s", glob.weight(), glob.typeName(), glob.pattern(), glob.caseSensitive());
        }
    }
}
