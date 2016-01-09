import std.stdio;
import std.exception;
import std.file;
import mime.files.magic;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <magic path>", args[0]);
    } else {
        
        void sink(MagicEntry t) {
            writefln("MimeType: %s. Priority: %s. Number of matches: %s. Should delete magic: %s", t.mimeType, t.magic.weight, t.magic.matches.length, t.magic.shouldDeleteMagic);
        }
        
        magicFileReader(assumeUnique(std.file.read(args[1])), &sink);
    }
}
