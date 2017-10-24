/**
 * MIME type store interface.
 * Implementers should be capable of returning requested MIME types if they exist.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 */

module mime.store;

public import std.range : InputRange;
public import std.typecons : Rebindable, rebindable;
public import mime.type;


/**
 * Interface for classes that store $(D mime.type.MimeType) objects.
 */
interface IMimeStore
{
    /**
     * All stored mime types.
     * Returns: Range of stored $(D mime.type.MimeType) objects.
     */
    InputRange!(const(MimeType)) byMimeType();

    /**
     * Get mime type for name.
     * Returns: $(D mime.type.MimeType) for given name.
     * Note:
     *  Implementer is not required to resolve alias if name happens to be alias.
     */
    Rebindable!(const(MimeType)) mimeType(const char[] name);
}
