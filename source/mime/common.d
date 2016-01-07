module mime.common;

package {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
    
    @nogc @system pure inout(char)[] fromCString(inout(char)* cString) nothrow {
        import std.c.string : strlen;
        return cString ? cString[0..strlen(cString)] : null;
    }
    
    static if (is(typeof({import std.string : fromStringz;}))) {
        import std.string : fromStringz;
    } else { //own fromStringz declaration for compatibility reasons
        @system pure inout(char)[] fromStringz(inout(char)* cString) {
            return fromCString(cString);
        }
    }
}

private {
    import std.typecons : Tuple;
}

auto parseMimeTypeName(String)(String name) if (is(String : const(char)[]))
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

bool isValidMimeTypeName(const(char)[] name)
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
