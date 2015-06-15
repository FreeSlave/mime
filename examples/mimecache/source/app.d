import std.stdio;
import mime.database.mimecache;

void main(string[] args)
{
    if (args.length < 2) {
        writefln("Usage: %s <mimecache file>", args[0]);
    } else {
        string fileName = args[1];
        readMimeCache(fileName);
    }
}
