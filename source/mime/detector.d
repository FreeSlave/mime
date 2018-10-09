/**
 * MIME type detector interface.
 * Implementers should be capable of detecting MIME type name by various properties including file name, file data and namespace uri.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.detector;

/**
 * Interface for classes that detect mime type name from file name or data.
 *
 * This interface is designed to know nothing about $(D mime.type.MimeType), it deals only with mime type names.
 * Implemented classes are not expected to be 'smart' (i.e. they should not do anything besides what required). See notes for member functions.
 */
interface IMimeDetector
{
    /**
     * The preferable mime type for fileName.
     * Returns: The name of preferable mime type for given fileName or null if could not find any match.
     * Note:
     *  Implementer is NOT expected to get the file data or state (e.g. read or stat it).
     */
    const(char)[] mimeTypeForFileName(const(char)[] fileName);

    /**
     * The list of the most preferred mime types for fileName.
     * If its length is greater than 1 it means there are many mime type with same priority matching this fileName.
     * Returns: Array of names of the most preferred mime types for given fileName.
     * Note:
     *  Implementer should prefer to return arrays with unique names.
     *  Implementer is NOT expected to get the file data or state (e.g. read or stat it).
     */
    const(char[])[] mimeTypesForFileName(const(char)[] fileName);

    /**
     * The preferable mime type for data.
     * Returns: The name of preferable mime type for given data or null if could not find any match.
     * Note:
     *  Implementer is NOT expected to check if data is textual or not in order to provide text/plain or application/octet-stream fallback.
     *  Implementer is NOT expected to clarify mime type by namespace uri itself if it was detected that data is xml.
     */
    const(char)[] mimeTypeForData(const(void)[] data);

    /**
     * The list of the most preferred mime types for data.
     * If its length is greater than 1 it means there are many mime type with same priority matching this data.
     * Returns: The array of the names of the most preferred mime types for given data.
     * Note:
     *  Implementer should prefer to return arrays with unique names.
     *  Implementer is NOT expected to check if data is textual or not in order to provide text/plain or application/octet-stream fallback.
     *  Implementer is NOT expected to clarify mime type by namespace uri itself if it was detected that data is xml.
     */
    const(char[])[] mimeTypesForData(const(void)[] data);

    /**
     * Returns: MIME type name for namespaceUri or null if not found (or feature is not implemented).
     */
    const(char)[] mimeTypeForNamespaceURI(const(char)[] namespaceURI);


    /**
     * Get real name of mime type by alias.
     * Returns: Resolved mime type name or null if not found (or feature not implemented).
     * Note:
     *  Implementer is not required to return aliasName itself if it's real name of mime type.
     */
    const(char)[] resolveAlias(const(char)[] aliasName);

    /**
     * Check if mimeType is subclass of parent.
     * Returns: true if mimeType is subclass of parent. False otherwise.
     * Note:
     *  Implementer is not required to treat mimeType as subclass of itself.
     */
    bool isSubclassOf(const(char)[] mimeType, const(char)[] parent);
}
