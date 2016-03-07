module mime.store;

public import std.range : InputRange;
public import std.typecons : Rebindable, rebindable;
public import mime.type;


/**
 * Interface for classes that store mime.type.MimeType objects.
 */
interface IMimeStore
{
    /**
     * All stored mime types.
     * Returns: Range of stored mime.type.MimeType objects.
     */
    InputRange!(const(MimeType)) byMimeType();
    
    /**
     * Get mime type for name.
     * Returns: mime.type.MimeType for given name.
     * Note:
     *  Implementer is not required to resolve alias if name happens to be alias.
     */
    Rebindable!(const(MimeType)) mimeType(const char[] name);
}
