/**
 * inode/* MIME types.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.inode;

version(Posix)
{
    import core.sys.posix.sys.stat;

    /**
     * Get mime type for stat mode.
     *
     * $(BLUE This function is Posix only).
     * Returns: inode/* mime type name for mode or null if unknown. Regular files don't have inode/* type.
     */
    @trusted string inodeMimeType(mode_t mode) nothrow
    {
        try {
            if (S_ISREG(mode)) {
                //skip
            } else if (S_ISDIR(mode)) {
                return "inode/directory";
            } else if (S_ISCHR(mode)) {
                return "inode/chardevice";
            } else if (S_ISBLK(mode)) {
                return "inode/blockdevice";
            } else if (S_ISFIFO(mode)) {
                return "inode/fifo";
            } else if (S_ISSOCK(mode)) {
                return "inode/socket";
            } else if (S_ISLNK(mode)) {
                return "inode/symlink";
            }
        } catch(Exception e) {
            //pass
        }
        return null;
    }

    ///
    unittest
    {
        assert(inodeMimeType(S_IFCHR) == "inode/chardevice");
        assert(inodeMimeType(S_IFBLK) == "inode/blockdevice");
        assert(inodeMimeType(S_IFIFO) == "inode/fifo");
        assert(inodeMimeType(S_IFSOCK) == "inode/socket");
    }
}

/**
 * Get inode mime type for file path.
 * Returns: inode/* mime type name for stated path or null if type is unknown or filePath targets regular file.
 * Note: On non-posix platforms it only cheks if filePath targets directory and returns inode/directory if so.
 */
@trusted string inodeMimeType(scope const(char)[] filePath) nothrow
{
    version(Posix) {
        import core.sys.posix.sys.stat;
        import std.string : toStringz;
        import std.path : buildNormalizedPath;

        stat_t statbuf;
        try {
            if (stat(toStringz(filePath), &statbuf) == 0) {
                if (S_ISDIR(statbuf.st_mode)) {
                    string parent = buildNormalizedPath(filePath, "..");
                    stat_t parentStatbuf;
                    if (stat(toStringz(parent), &parentStatbuf) == 0) {
                        if (parentStatbuf.st_dev != statbuf.st_dev) {
                            return "inode/mount-point";
                        }
                    }
                }
                return inodeMimeType(statbuf.st_mode);
            }
        } catch(Exception e) {
            //pass
        }

        return null;
    } else {
        import std.exception;
        import std.file;
        bool ok;
        collectException(filePath.isDir, ok);
        if (ok) {
            return "inode/directory";
        } else {
            return null;
        }
    }
}

///
unittest
{
    assert(inodeMimeType("source") == "inode/directory"); //directory
    assert(inodeMimeType("dub.json") is null); //regular file
    assert(inodeMimeType("test/|nonexistent|") is null); //nonexistent path
}
