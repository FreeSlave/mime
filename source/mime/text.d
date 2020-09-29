/**
 * Text utility functions.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Copyright:
 *  Roman Chistokhodov, 2016
 */

module mime.text;

private @safe bool isValidUnicodeTail(scope const(char)[] tail) nothrow pure
{
    for (size_t i=0; i<tail.length; ++i) {
        if ( !(0b1000_0000 & tail[i]) || !(0b0100_0000 & ~cast(int)(tail[i])) ) {
            return false;
        }
    }
    return true;
}

/**
 * Check if data seems to be textual. Can be used to choose whether to use text/plain or application/octet-stream as fallback.
 * Returns: True if data seems to be textual, false otherwise.
 * Note: Empty data is not considered to be textual.
 */
@trusted bool isTextualData(scope const(void)[] data) nothrow pure
{
    import std.utf;
    import std.uni;

    if (!data.length) {
        return false;
    }

    auto str = cast(const(char)[])data;

    size_t index;
    try {
        while (index < str.length) {
            dchar c = decode(str, index);
            if (c.isNonCharacter || c.isPrivateUse) {
                return false;
            }
            import std.ascii;
            if (isASCII(c) && (!std.ascii.isPrintable(c) && !std.ascii.isWhite(c))) {
                return false;
            }
        }
    }
    catch(Exception e) {
        auto tail = str[index+1..$];
        if (tail.length < 3 && isValidUnicodeTail(tail)) {
            auto s = str[index];
            if (((0b1111_0000 & s) == 0b1111_0000) && (0b0000_1000 & ~cast(int)s)) {
                return tail.length < 3;
            } else if (((0b1110_0000 & s) == 0b1110_0000) && (0b0001_0000 & ~cast(int)s)) {
                return tail.length < 2;
            } else if (((0b1100_0000 & s) == 0b1100_0000) && (0b0010_0000 & ~cast(int)s)) {
                return tail.length < 1;
            }
        }
        return false;
    }

    return true;
}

///
unittest
{
    assert(isTextualData("English"));
    assert(isTextualData("日本語"));
    assert(isTextualData("Русский язык"));
    assert(isTextualData("English and кириллица"));
    assert(isTextualData("Copyright ©"));
    assert(isTextualData("0A a!\n\r\t~(){}.?"));
    assert(isTextualData("Hello \U0001F603"));

    assert(isTextualData("日本語"[0..$-1]));
    assert(isTextualData("Русский язык"[0..$-1]));
    assert(isTextualData("Hello \U0001F603"[0..$-1]));
    assert(isTextualData("text \u00A2"[0..$-1]));

    assert(!isTextualData("text\U000F0000text"));//private use

    assert(!isTextualData(""));
    assert(!isTextualData("abc\x01"));
    assert(!isTextualData("\xFF\xFE"));
    assert(!isTextualData("\xd0\x54"));
    assert(!isTextualData("\x10"));
}
