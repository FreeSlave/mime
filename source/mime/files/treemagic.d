/**
 * Parsing mime/treemagic files.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.files.treemagic;

public import mime.treemagic;
import mime.common;

private {
    import std.algorithm;
    import std.bitmanip;
    import std.conv;
    import std.exception;
    import std.path;
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

alias Tuple!(immutable(char)[], "mimeType", TreeMagic, "magic") TreeMagicEntry;

private @trusted TreeMatch parseTreeMatch(ref immutable(char)[] current, uint myIndent)
{
    enforce(current.length && current[0] == '>', "Expected '>' at the start of match rule");
    current = current[1..$];
    enforce(current.length && current[0] == '"', "Expected \" before path");
    current = current[1..$];
    
    auto result = findSplit(current, "\"");
    enforce(result[1].length, "Could not find \" in the end of path");
    
    auto path = result[0];
    enforce(path.isValidPath, "Path in treematch must be valid");
    current = result[2];
    
    enforce(current.length && current[0] == '=', "Expected '=' after path");
    current = current[1..$];
    
    TreeMatch.Type type;
    if (current.startsWith("file")) {
        type = TreeMatch.Type.file;
        current = current["file".length..$];
    } else if (current.startsWith("directory")) {
        type = TreeMatch.Type.directory;
        current = current["directory".length..$];
    } else if (current.startsWith("link")) {
        type = TreeMatch.Type.link;
        current = current["link".length..$];
    } else if (current.startsWith("any")) {
        type = TreeMatch.Type.any;
        current = current["any".length..$];
    } else {
        throw new Exception("Unknown path type");
    }
    
    auto endResult = findSplit(current, "\n");
    enforce(endResult[1].length, "Could not find new line character in the end of treematch section");
    
    TreeMatch.Options options;
    string mimeType;
    auto optionsStr = endResult[0];
    if (optionsStr.length) {
        enforce(optionsStr[0] == ',', "Comma is expected when options are presented");
        optionsStr = optionsStr[1..$];
        auto byOption = optionsStr.splitter(",");
        foreach(option; byOption) {
            if (option == "executable") {
                options |= TreeMatch.Options.executable;
            } else if (option == "match-case") {
                options |= TreeMatch.Options.matchCase;
            } else if (option == "non-empty") {
                options |= TreeMatch.Options.nonEmpty;
            } else {
                if (isValidMimeTypeName(option)) {
                    options |= TreeMatch.Options.mimeType;
                    mimeType = option;
                } else {
                    throw new Exception("Unexpected option" ~ option);
                }
            }
        }
    }
    
    current = endResult[2];
    
    auto match = TreeMatch(path, type, options);
    if ((options & TreeMatch.Options.mimeType)) {
        match.mimeType = mimeType;
    }
    
    //read sub rules
    while (current.length && current[0] != '[') {
        auto copy = current;
        uint indent = parseIndent(copy);
        if (indent > myIndent) {
            current = copy;
            TreeMatch submatch = parseTreeMatch(current, indent);
            match.addSubmatch(submatch);
        } else {
            break;
        }
    }
    
    return match;
}

//TODO: duplicated in mime.files.magic
private uint parseIndent(ref immutable(char)[] current)
{
    enforce(current.length);
    uint indent = 0;
    
    if (current[0] != '>') {
        indent = parse!uint(current);
    }
    return indent;
}

/**
 * Reads treemagic file contents and push treemagic entries to sink.
 * Throws: 
 *  $(D TreeMagicFileException) on error.
 */
void treeMagicFileReader(OutRange)(immutable(void)[] data, OutRange sink) if (isOutputRange!(OutRange, TreeMagicEntry))
{
    try {
        enum mimeMagic = "MIME-TreeMagic\0\n";
        auto content = cast(immutable(char)[])data;
        if (!content.startsWith(mimeMagic)) {
            throw new Exception("Not treemagic file");
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
                
                TreeMatch match = parseTreeMatch(current, indent);
                magic.addMatch(match);
            }
            sink(TreeMagicEntry(mimeType, magic));
        }
    } catch (Exception e) {
        throw new TreeMagicFileException(e.msg, e.file, e.line, e.next);
    }
}

///
unittest
{
    auto data = 
    "MIME-TreeMagic\0\n[50:x-content/video-bluray]\n"
        ">\"BDAV\"=directory,non-empty\n"
            "1>\"autorun\"=file,executable,match-case\n";
    
    void sink(TreeMagicEntry t) {
        assert(t.mimeType == "x-content/video-bluray");
        assert(t.magic.weight == 50);
        assert(t.magic.matches.length == 1);
        
        auto submatch = t.magic.matches[0];
        assert(submatch.path == "BDAV");
        assert(submatch.type == TreeMatch.Type.directory);
        assert(submatch.options == TreeMatch.Options.nonEmpty);
        assert(submatch.submatches.length == 1);
        
        auto autorun = submatch.submatches[0];
        assert(autorun.path == "autorun");
        assert(autorun.submatches.length == 0);
        assert(autorun.type == TreeMatch.Type.file);
        assert(autorun.options == (TreeMatch.Options.executable | TreeMatch.Options.matchCase));
    }
    treeMagicFileReader(data, &sink);
    
    void emptySink(TreeMagicEntry t) {
        
    }
    assertThrown!TreeMagicFileException(treeMagicFileReader("MIME-wrong-magic", &emptySink));
}
