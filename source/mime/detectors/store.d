module mime.detectors.store;

import mime.detector;


private @nogc @trusted bool hasGlobMatchSymbols(string s) nothrow pure {
    static @nogc @safe bool isGlobMatchSymbol(char c) nothrow pure {
        return c == '*' || c == '?' || c == '[';
    }
    
    for (size_t i=0; i<s.length; ++i) {
        if (isGlobMatchSymbol(s[i])) {
            return true;
        }
    }
    return false;
}

// class StoreMimeDetector : IMimeDetector
// {
//     this(IMimeStore store) {
//         _store = store;
//         
//         foreach(mimeType; store.byMimeType()) {
//             string pattern = mimeType.pattern;
//             if (!pattern.empty) {
//                 if (pattern.startsWith("*") && pattern.length > 1 && !pattern[2..$].hasGlobMatchSymbols) {
//                     addGlob(mimeType, _suffixes, pattern[1..$]);
//                 } else if (pattern.hasGlobMatchSymbols) {
//                     addGlob(mimeType, _otherGlobs, pattern);
//                 } else {
//                     addGlob(mimeType, _literals, pattern);
//                 }
//             }
//             
//             foreach(aliasName; mimeType.aliases) {
//                 _aliases[aliasName] = mimeType;
//             }
//         }
//     }
//     
//     const(IMimeStore) store() {
//         return _store;
//     }
//     
// private:
//     @trusted void addGlob(const(MimeType)* mimeType, ref const(MimeType)*[][string] globs, string pattern) {
//         auto mimeTypesPtr = pattern in globs;
//         if (mimeTypesPtr) {
//             *mimeTypesPtr ~= mimeType;
//         } else {
//             globs[pattern] = [mimeType];
//         }
//     }
//     
//     IMimeStore _store;
//     const(MimeType)[string] _aliases;
//     const(MimeType)[][string] _suffixes; 
//     const(MimeType)[][string] _literals;
//     const(MimeType)[][string] _otherGlobs; 
// }
