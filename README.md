# Mime

[Shared MIME-info database](http://standards.freedesktop.org/shared-mime-info-spec/shared-mime-info-spec-latest.html) specification implementation in D programming language.

[![Build Status](https://travis-ci.org/MyLittleRobo/mime.svg?branch=master)](https://travis-ci.org/MyLittleRobo/mime)

## Generating documentation

Ddoc:

    dub build --build=docs
    
Ddox:

    dub build --build=ddox

## Examples

### MimeCache

Run to detect mime type of README.md or other files using mime.cache:

    dub run mime:mimecache -- --mimecache=/usr/share/mime/mime.cache README.md lib/libmime.a Makefile CMakeLists.txt test.c test.C test.cpp test.xml

Run to detect mime type of files using using mime.cache including its magic rules.
    
    dub run mime:mimecache -- --useMagic --mimecache=/usr/share/mime/mime.cache examples/mimecache/bin/mimecache lib/libmime.a

    
### MimeDatabase

Print short information on all found MIME types.

    dub run mime:mimedatabase -- --printDatabase=true

Run to detect mime types of files.

    dub run mime:mimedatabase -- --file=README.md --file=source --file=.gitignore --file=lib/libmime.a
    
## TODO

1. Implement MIME type detection from file contents (via magic).
2. Read MIME types from mime/packages sources (need xml library).
3. Determine MIME type by XMLnamespace if document is xml (need streaming xml library).
4. Implement merging of many files into one database (user defined one from .local/share/mime should be used before system-wide defined /usr/share/mime).
5. Allow to create MIME types (need xml library) and call update-mime-database.

## Interface and implementation discussion

Which interfaces library should provide? The obvious way is to make MimeType and MimeDatabase classes. 
But there're at least 3 ways to read mime database:

1. From mime.cache. It lacks additional information (like comments, acronyms and additional fields), optimized for lookup, but not for storing MIME types as separate objects).
2. From various generated files like globs, icons, magic, etc (not optimized, also lacks information, but easy to read).
3. From mime/packages sources. It's straight-forward and the most complete (in sense it does not lose any information) way, but requires XML parsing.

All can be implemented as different MimeDatabase classes inherited the same interface.

What about thread safety?

MimeType matters:

1. Should MimeType be class or struct?
2. Should MimeType be independent from database it was read from?
3. Should MimeType always preserve all information if it was loaded from xml source?

Should MimeDatabse detect MIME types for non-regular files? (inode/directory, etc.)
Should MimeDatabse distinguish between text and binary data (text/plain vs application/octet-stream) when could not determine MIME type?
