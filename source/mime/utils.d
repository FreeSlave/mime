/**
 * Various utility functions.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.utils;

private import mime.common;

version(Posix)
{
    import core.sys.posix.sys.stat;
    
    /**
     * Get mime type from stat mode.
     * Returns: inode/* mime type name for mode or null if unknown. Regular files don't have inode/* type.
     * Note: This function is Posix-only.
     */
    @nogc @trusted string inodeMimeType(mode_t mode) nothrow
    {
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
        
        return null;
    }
}

/**
 * Check if data seems to be textual. Can be used to choose whether to use text/plain or application/octet-stream as fallback.
 * Returns: True if data seems to be textual, false otherwise.
 * Note: Empty data is not considered to be textual.
 */
@nogc @trusted bool isTextualData(const(void)[] data) pure nothrow
{
    //TODO: utf-8 support
    import std.ascii;
    if (data.length == 0) {
        return false;
    }
    
    auto str = cast(const(char)[])data;
    for(size_t i=0; i<str.length; ++i) {
        if (str[i].isPrintable || str[i].isWhite) {
            continue;
        } else {
            return false;
        }
    }
    return true;
}

///
unittest
{
    const(ubyte)[] data;
    data = [1];
    assert(!isTextualData(data));
    data = [16];
    assert(!isTextualData(data));
    data = cast(const(ubyte)[])"0A a!\n\r\t~(){}.?";
    assert( isTextualData(data));
}
