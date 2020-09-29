/**
 * Common functions and constants to work with MIME types.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.common;

// should be enough for magic rules
package enum dataSizeToRead = 1024 * 4;

private {
    import std.typecons;
    import std.traits;
    import std.range;
}

/**
 * Parse MIME type name into pair of media and subtype strings.
 * Returns: Tuple of media and subtype strings or pair of empty strings if could not parse name.
 */
@nogc @trusted auto parseMimeTypeName(String)(scope return String name) pure nothrow if (isSomeString!String && is(ElementEncodingType!String : char))
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
    assert(t.media == string.init && t.subtype == string.init);
}

private @nogc @trusted bool allSymbolsAreValid(scope const(char)[] name) nothrow pure
{
    import std.ascii : isAlpha, isDigit;
    for (size_t i=0; i<name.length; ++i) {
        char c = name[i];
        if (!(c.isAlpha || c.isDigit || c == '-' || c == '+' || c == '.' || c == '_')) {
            return false;
        }
    }
    return true;
}

/**
 * Check if name is valid MIME type name.
 */
@nogc @safe bool isValidMimeTypeName(scope const(char)[] name) nothrow pure
{
    auto t = parseMimeTypeName(name);
    return t.media.length && t.subtype.length && allSymbolsAreValid(t.media) && allSymbolsAreValid(t.subtype);
}

///
unittest
{
    assert( isValidMimeTypeName("text/plain"));
    assert( isValidMimeTypeName("text/plain2"));
    assert( isValidMimeTypeName("text/vnd.type"));
    assert( isValidMimeTypeName("x-scheme-handler/http"));
    assert(!isValidMimeTypeName("not mime type"));
    assert(!isValidMimeTypeName("not()/valid"));
    assert(!isValidMimeTypeName("not/valid{}"));
    assert(!isValidMimeTypeName("text/"));
    assert(!isValidMimeTypeName("/plain"));
    assert(!isValidMimeTypeName("/"));
}

/**
 * Default icon for MIME type.
 * Returns: mimeType with '/' replaces with '-' or null if mimeType is not valid MIME type name.
 */
@safe string defaultIconName(scope string mimeType) nothrow pure
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
@trusted string defaultGenericIconName(scope string mimeType) nothrow pure
{
    auto t = parseMimeTypeName(mimeType);
    if (t.media.length) {
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
/// Maximum glob pattern weight as defined by spec.
enum uint maximumGlobWeight = 100;

/// Default magic rule priority to use when it's not explicitly provided.
enum uint defaultMatchWeight = 50;
/// Maximum magic rule priority as defined by spec.
enum uint maximumMatchWeight = 100;

/**
 * Check is pattern is __NOGLOBS__. This means glob patterns from the less preferable MIME paths should be ignored.
 */
@nogc @safe bool isNoGlobs(T)(scope const(T)[] pattern) pure nothrow if (is(T == char) || is(T == ubyte) || is(T == byte) || is(T == void)) {
    return cast(const(ubyte)[])pattern == cast(const(ubyte)[])"__NOGLOBS__";
}

///
unittest
{
    assert(isNoGlobs("__NOGLOBS__"));
    assert(!isNoGlobs("someglob"));
}

/**
 * Check if value is __NOMAGIC__. This means magic rules from the less preferable MIME paths should be ignored.
 */
@nogc @trusted bool isNoMagic(T)(scope const(T)[] value) pure nothrow if (is(T == char) || is(T == ubyte) || is(T == byte) || is(T == void)) {
    return cast(const(ubyte)[])value == cast(const(ubyte)[])"__NOMAGIC__";
}

///
unittest
{
    assert(isNoMagic("__NOMAGIC__"));
    assert(!isNoMagic("somemagic"));
}

/**
 * Get implicit parent type if mimeType. This is text/plain for all text/* types
 * and application/octet-stream for all streamable types.
 * Returns: text/plain for text-based types, application/octet-stream for streamable types, null otherwise.
 * Note: text/plain and application/octet-stream are not considered as parents of their own.
 */
@safe string implicitParent(scope const(char)[] mimeType) nothrow pure
{
    if (mimeType == "text/plain" || mimeType == "application/octet-stream") {
        return null;
    }

    auto t = parseMimeTypeName(mimeType);
    if (t.media == "text") {
        return "text/plain";
    } else if ( t.media == "image" || t.media == "audio" ||
                t.media == "video" || t.media == "application")
    {
        return "application/octet-stream";
    }
    return null;
}

///
unittest
{
    assert(implicitParent("text/hmtl") == "text/plain");
    assert(implicitParent("text/plain") == null);

    assert(implicitParent("image/png") == "application/octet-stream");
    assert(implicitParent("audio/ogg") == "application/octet-stream");
    assert(implicitParent("video/mpeg") == "application/octet-stream");
    assert(implicitParent("application/xml") == "application/octet-stream");
    assert(implicitParent("application/octet-stream") == null);

    assert(implicitParent("inode/directory") == null);
    assert(implicitParent("x-content/unix-software") == null);

    assert(implicitParent("not a mimetype") == null);
}
