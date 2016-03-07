/**
 * inode/* MIME types.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
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
     * Get mime type from stat mode.
     * Returns: inode/* mime type name for mode or null if unknown. Regular files don't have inode/* type.
     * Note: This function is Posix-only.
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
}

/**
 * Get inode mime type by fileName.
 * Returns: inode/* mime type name for stated file or null if type is unknown or fileName targets regular file.
 * Note: On non-posix platforms it only cheks if fileName targets directory and returns inode/directory is so.
 */
@trusted string inodeMimeType(string fileName) nothrow
{
    version(Posix) {
        import core.sys.posix.sys.stat;
        import std.string : toStringz;
        
        stat_t statbuf;
        try {
            if (stat(toStringz(fileName), &statbuf) == 0) {
                return inodeMimeType(statbuf.st_mode);
            }
        } catch(Exception e) {
            //pass
        }
        
        return null;
    } else {
        bool ok;
        collectException(fileName.isDir, ok);
        if (ok) {
            return "inode/directory";
        } else {
            return null;
        }
    }
}
