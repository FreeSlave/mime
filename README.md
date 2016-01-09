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

    dub run mime:mimecache -- README.md lib/libmime.a Makefile CMakeLists.txt test.c test.C test.cpp test.xml

Run to detect mime type of files using using mime.cache including its magic rules.
    
    dub run mime:mimecache -- --useMagic examples/mimecache/bin/mimecache lib/libmime.a

    
### MimeDatabase

Print short information on all found MIME types.

    dub run mime:mimedatabase -- --printDatabase=true

Run to detect mime types of files.

    dub run mime:mimedatabase -- --file=README.md --file=source --file=.gitignore --file=lib/libmime.a
    
## TODO

1. Implement MIME type detection from file contents (via magic, parially done).
2. Read MIME types from mime/packages sources (requires xml library).
3. Determine MIME type by XMLnamespace if document is xml (requires streaming xml library).
4. Allow to create MIME types (requires xml library) and call update-mime-database.
