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
