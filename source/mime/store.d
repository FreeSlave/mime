module mime.store;

public import std.range : InputRange;
public import mime.type;


/**
 * Interfaces for classes that store objects of mime.type.MimeType.
 */
interface IMimeStore
{
    InputRange!(const(MimeType)) byMimeType();
    const(MimeType) mimeType(const char[] name);
}
