# Mime

[Shared MIME-info database](https://www.freedesktop.org/wiki/Specifications/shared-mime-info-spec/) specification implementation in D programming language. Shared MIME-info database helps to determine media type of file by its name or contents.

[![Build Status](https://travis-ci.org/FreeSlave/mime.svg?branch=master)](https://travis-ci.org/FreeSlave/mime) [![Coverage Status](https://coveralls.io/repos/github/FreeSlave/mime/badge.svg?branch=master)](https://coveralls.io/github/FreeSlave/mime?branch=master)

[Online documentation](https://freeslave.github.io/d-freedesktop/docs/mime.html)

## Features

### Implemented features

* Reading and using mime.cache files to match file names against glob patterns, match file contents against magic rules, resolve aliases and find mime type parents.
* Reading various shared MIME-info database files in mime/ subfolder, e.g. globs2, magic and others.
* treemagic support.

### Missing features

* Reading MIME types from mime/packages sources and mime/MEDIA folders (requires xml library).
* Determining MIME type by XMLnamespace if document is xml (requires streaming xml library).

## Examples
    
### [Mime Database](examples/database/source/app.d)

Run to detect mime types of files.

    dub run :database -- detect README.md source .gitignore lib/libmime.a examples/database/bin/mime_database /var/run/acpid.socket dub.json /dev/sda
    
Automated mime path detection works only on Freedesktop platforms. On other systmes or for testing purposes it's possible to use mimepath option to set alternate path to mime/ subfolder. E.g. on Windows with KDE installed it would be:

    dub run :database -- --mimepath=C:\ProgramData\KDE\share\mime detect README.md source .gitignore lib/mime.lib examples/mimedatabase/bin/mimedatabase.exe dub.json
    
Run to print info about MIME types:

    dub run :database -- info application/pdf application/x-executable image/png text/plain text/html text/xml

Run to resolve aliases:

    dub run :database -- resolve application/wwf application/x-pdf application/pgp text/rtf text/xml
    
### [Mime Test](examples/test/source/app.d)

Run to test if this library is capable of parsing your local shared MIME-info database:

    dub run :test
    
As with mimedatabase example you may specify paths to *mime* folder(s) via command line:

    dub run :test -- --mimepath=C:\ProgramData\KDE\share\mime
