module mime.common;

package {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
    
    static if (is(typeof({import std.string : fromStringz;}))) {
        import std.string : fromStringz;
    } else { //own fromStringz implementation for compatibility reasons
        import std.c.string : strlen;
        @system pure inout(char)[] fromStringz(inout(char)* cString) {
            return cString ? cString[0..strlen(cString)] : null;
        }
    }
}
