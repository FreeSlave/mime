import std.stdio;
import mime.mimedatabase;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <mime.cache path>", args[0]);
    } else {
        auto database = new MimeDatabase(args[1]);
    }
}
