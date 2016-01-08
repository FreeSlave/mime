module mime.common;

package {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

private {
    import std.typecons : Tuple;
}

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
