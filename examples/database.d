/+dub.sdl:
name "database"
dependency "mime" path="../"
+/

import std.stdio;
import std.getopt;
import std.array;
import std.typecons;

import mime.database;
import mime.paths;

void detectTypes(MimeDatabase database, string[] filePaths)
{
    foreach(filePath; filePaths) {
        writefln("MIME type of '%s' according to", filePath);

        auto mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.globPatterns);
        writefln("\tglob patterns:\t%s", mimeType ? mimeType.name : "unknown");

        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.magicRules|MimeDatabase.Match.namespaceURI);
        writefln("\tmagic rules:\t%s", mimeType ? mimeType.name : "unknown");

        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.textFallback | MimeDatabase.Match.octetStreamFallback | MimeDatabase.Match.emptyFileFallback);
        writefln("\ttext or binary:\t%s", mimeType ? mimeType.name : "unknown");

        mimeType = database.mimeTypeForFile(filePath, MimeDatabase.Match.inodeType);
        writefln("\tinode type:\t%s", mimeType ? mimeType.name : "unknown (regular file?)");
    }
}

void printInfo(MimeDatabase database, string[] mimeTypes)
{
    foreach(type; mimeTypes) {
        auto mimeType = database.mimeType(type);
        if (mimeType is null) {
            writefln("Could not find mime type named %s\n", type);
        } else {
            import std.algorithm.iteration : map;
            import std.format : format;
            writefln("Information for %s:", type);
            writefln("MIME type: %s", mimeType.name);
            writefln("Descriptive name: %s", mimeType.displayName);
            writefln("Icon: %s", mimeType.getIcon());
            writefln("Generic-Icon: %s", mimeType.getGenericIcon());
            writefln("Aliases: %s", mimeType.aliases);
            writefln("Parents: %s", mimeType.parents);
            writefln("Glob patterns: %-(%s, %)", mimeType.globs.map!(glob => format(`("%s":%s%s)`, glob.pattern, glob.weight, glob.caseSensitive ? ":case-sensitive" : "")));
            writeln();
        }
    }
}

void resolveAliases(MimeDatabase database, string[] aliases)
{
    foreach(nameOrAlias; aliases) {
        auto mimeType = database.mimeType(nameOrAlias, Yes.resolveAlias);
        if (!mimeType) {
            writefln("Could not resolve alias %s", nameOrAlias);
        } else {
            if (mimeType.name == nameOrAlias) {
                writefln("%20s is real name, not alias", nameOrAlias);
            } else {
                writefln("%-20s is alias for %s", nameOrAlias, mimeType.name);
            }
        }
    }
}

void main(string[] args)
{
    string[] mimePaths;
    getopt(args,
        "mimepath", "Set mime path to search files in.", &mimePaths
    );

    version(OSX) {} else version(Posix) {
        if (!mimePaths.length) {
            mimePaths = mime.paths.mimePaths().array;
        }
    }
    if (!mimePaths.length) {
        stderr.writeln("No mime paths set");
        return;
    }

    auto database = new MimeDatabase(mimePaths);

    string[] posArgs;
    string command;
    if (args.length < 2) {
        stderr.writeln("expected command");
        return;
    } else {
        posArgs = args[2..$];
        command = args[1];
    }

    switch(command) {
        case "detect":
        {
            detectTypes(database, posArgs);
        }
        break;
        case "info":
        {
            printInfo(database, posArgs);
        }
        break;
        case "resolve":
        {
            resolveAliases(database, posArgs);
        }
        break;
        default: {
            stderr.writefln("Unknown command: %s", command);
        }
    }
}
