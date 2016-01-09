module mime.common;

package {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

private {
    import std.typecons : Tuple;
}

/**
 * Parse MIME type name into pair of media and subtype strings.
 * Returns: Tuple of media and subtype strings or pair of empty strings if could not parse name.
 */
@trusted auto parseMimeTypeName(String)(String name) if (is(String : const(char)[]))
{
    alias Tuple!(String, "media", String, "subtype") MimeTypeName;
    
    String media;
    String subtype;
    
    size_t i;
    for (i=0; i<name.length; ++i) {
        if (name[i] == '/') {
            media = name[0..i];
            subtype = name[i+1..$];
            break;
        }
    }
    
    return MimeTypeName(media, subtype);
}

///
unittest
{
    auto t = parseMimeTypeName("text/plain");
    assert(t.media == "text" && t.subtype == "plain");
    
    t = parseMimeTypeName("not mime type");
    assert(t.media is null && t.subtype is null);
}

/**
 * Check if name is valid MIME type name.
 */
@nogc @safe bool isValidMimeTypeName(const(char)[] name) nothrow pure
{
    auto t = parseMimeTypeName(name);
    return t.media.length && t.subtype.length;
}

///
unittest
{
    assert( isValidMimeTypeName("text/plain"));
    assert(!isValidMimeTypeName("not mime type"));
}

/**
 * Default icon for MIME type.
 * Returns: mimeType with '/' replaces with '-' or null if mimeType is not valid MIME type name.
 */
@trusted string defaultIconName(string mimeType) nothrow pure
{
    auto t = parseMimeTypeName(mimeType);
    if (t.media.length && t.subtype.length) {
        return t.media ~ "-" ~ t.subtype;
    }
    return null;
}

///
unittest
{
    assert(defaultIconName("text/plain") == "text-plain");
    assert(defaultIconName("not mime type") == string.init);
}

/**
 * Default generic icon for MIME type.
 * Returns: media-x-generic where media is parsed from mimeType or null if mimeType is not valid MIME type name.
 */
@trusted string defaultGenericIconName(string mimeType) nothrow pure
{
    auto t = parseMimeTypeName(mimeType);
    if (t.media) {
        return t.media ~ "-x-generic";
    }
    return null;
}

///
unittest
{
    assert(defaultGenericIconName("image/type") == "image-x-generic");
    assert(defaultGenericIconName("not mime type") == string.init);
}

/// Default glob pattern weight to use when it's not explicitly provided.
enum uint defaultGlobWeight = 50;

/// Default magic match rule priority to use when it's not explicitly provided.
enum uint defaultMatchWeight = 50;

