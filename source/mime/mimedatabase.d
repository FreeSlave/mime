module mime.mimedatabase;

private {
    import std.mmfile;
    
    import std.algorithm;
    
    import std.exception;
    import std.traits;
    import std.bitmanip;
    import std.system;
    import std.typecons;
    
    import std.stdio;
}

import mime.mimetype;

private static void swapByteOrder(T)(ref T t) {
    t = swapEndian(t);
}

struct MimeCacheHeader
{
    ushort majorVersion;
    ushort minorVersion;
    uint aliasListOffset;
    uint parentListOffset;
    uint literalListOffset;
    uint reverseSuffixTreeOffset;
    uint globListOffset;
    uint magicListOffset;
    uint namespaceListOffset;
    uint iconsListOffset;
    uint genericIconsListOffset;
}

class MimeDatabase
{
    this(in string[] mimePaths) {
        update(mimePaths);
    }
    
    this(string mimeCachePath) {
        
    }
    
    void update(in string[] mimePaths) {
        _mimePaths = mimePaths;
        update();
    }
    
    void update() {
        
    }
    
    const(string)[] mimePaths() const {
        return _mimePaths;
    }
    
    const(MimeType)* mimeType(string name) const {
        auto mType = name in _mimeTypes;
        if (mType) {
            return mType;
        } else {
            auto mimeNames = name in _aliases;
            if (mimeNames) {
                foreach(mimeName; *mimeNames) {
                    mType = mimeName in _mimeTypes;
                    if (mType) {
                        return mType;
                    }
                }
            }
        }
        return null;
    }
    
    const(MimeType)* mimeTypeForFileName(string fileName) const {
        return null;
    }
    
    const(MimeType)* mimeTypeForData(const(void)[] data) const {
        return null;
    }
    
private:
    
    MimeType* ensureMimeType(const(char)[] name) {
        MimeType* mimeType = name in _mimeTypes;
        if (mimeType) {
            return mimeType;
        } else {
            string mimeName = name.idup;
            _mimeTypes[mimeName] = MimeType(mimeName);
            return mimeName in _mimeTypes;
        }
    }
    
    const(string)[] _mimePaths;
    MmFile mmaped;
    MimeType[const(char)[]] _mimeTypes;
    string[][string] _aliases;
}

