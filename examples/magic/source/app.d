import std.stdio;
import mime.database.magic;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <magic path>", args[0]);
    } else {
        auto magic = magicFileReader(args[1]);
    }
}
