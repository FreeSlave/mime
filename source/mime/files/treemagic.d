module mime.files.treemagic;

public import mime.treemagic;
import mime.common;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.conv;
    import std.exception;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
}

///Exception thrown on parse errors while reading treemagic file.
final class TreeMagicFileException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
    }
}

alias Tuple!(immutable(char)[], "mimeType", MimeMagic, "magic") TreeMagicEntry;

/**
 * Reads treemagic file contents and push treemagic entries to sink.
 * Throws: 
 *  TreeMagicFileException on error.
 */
void treeMagicFileReader(OutRange)(immutable(void)[] data, OutRange sink) if (isOutputRange!(OutRange, TreeMagicEntry))
{
    try {
        enum mimeMagic = "MIME-TreeMagic\0\n";
        auto content = cast(immutable(char)[])data;
        if (!content.startsWith(mimeMagic)) {
            throw new Exception("Not mime magic file");
        }
        
        auto current = content[mimeMagic.length..$];
        
        while(current.length) {
            enforce(current[0] == '[', "Expected '[' at the start of magic section");
            current = current[1..$];
            
            auto result = findSplit(current[0..$], "]\n");
            enforce(result[1].length, "Could not find \"]\\n\"");
            current = result[2];
            
            auto sectionResult = findSplit(result[0], ":");
            enforce(sectionResult[1].length, "Priority and MIME type must be splitted by ':'");
            
            uint priority = parse!uint(sectionResult[0]);
            auto mimeType = sectionResult[2];
            
            auto magic = TreeMagic(priority);
            
            while (current.length && current[0] != '[') {
                uint indent = parseIndent(current);
                
                MagicMatch match = parseMagicMatch(current, indent);
                if (isNoMagic(match.value)) {
                    magic.shouldDeleteMagic = true;
                } else {
                    magic.addMatch(match);
                }
            }
            sink(MagicEntry(mimeType, magic));
        }
    } catch (Exception e) {
        throw new TreeMagicFileException(e.msg, e.file, e.line, e.next);
    }
}
