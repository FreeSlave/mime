# Mime

[Shared MIME-info database](http://standards.freedesktop.org/shared-mime-info-spec/shared-mime-info-spec-latest.html) specification implementation in D programming language.

[![Build Status](https://travis-ci.org/MyLittleRobo/mime.svg?branch=master)](https://travis-ci.org/MyLittleRobo/mime)

## Generating documentation

Ddoc:

    dub build --build=docs
    
Ddox:

    dub build --build=ddox

## Examples

### [MimeCache](examples/mimecache/source/app.d)

Run to detect mime type of README.md or other files using mime.cache:

    dub run mime:mimecache -- README.md lib/libmime.a Makefile CMakeLists.txt test.c test.C test.cpp test.xml

Run to detect mime type of files via magic rules.
    
    dub run mime:mimecache -- --useMagic examples/mimecache/bin/mimecache lib/libmime.a

    
### [MimeDatabase](examples/mimedatabase/source/app.d)

Run to detect mime types of files.

    dub run mime:mimedatabase -- README.md source .gitignore lib/libmime.a examples/mimedatabase/bin/mimedatabase /var/run/acpid.socket dub.selections.json
    
Automated mime path detection works only on Freedesktop platforms. On other systmes or for testing purposes it's possible to use mimepath option to set alternate path to mime/ subfolder. E.g. on Windows with KDE installed it would be:

    dub run mime:mimedatabase -- --mimepath=C:\ProgramData\KDE\share\mime README.md source .gitignore lib/libmime.a examples/mimedatabase/bin/mimedatabase.exe dub.selections.json
    
## Features

### Implemented features

* Reading mime.cache files.
* Using mime.cache files to match file names against glob patterns, match file contents against magic rules (not fully implemented yet, but works in most cases) and resolve aliases.
* Reading various files in mime/ subfolder, e.g. globs2, magic and others.

### Missing features

* Reading MIME types from mime/packages sources (requires xml library).
* Determining MIME type by XMLnamespace if document is xml (requires streaming xml library).
