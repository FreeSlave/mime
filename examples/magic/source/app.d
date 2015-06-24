import std.stdio;
import mime.database.magic;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <magic path>", args[0]);
    } else {
        auto magic = magicFileReader(args[1]);
        foreach(section; magic) {
            writefln("Mime Type: %s. Priority: %s", section.mimeType, section.priority);
            foreach(line; section.lines) {
                writefln("Indent: %s, startOffset: %s, valueLength: %s, value: %s, mask: %s, wordSize: %s, rangeLength: %s",
                        line.indent, line.startOffset, line.valueLength, line.value, line.mask, line.wordSize, line.rangeLength
                );
            }
        }
    }
}
