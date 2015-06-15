module mime.mimedatabase;

import mime.mimetype;

class MimeDatabase
{
    this(in string[] mimePaths) {
        update(mimePaths);
    }
    
    void update(in string[] mimePaths) {
        _mimePaths = mimePaths;
        update();
    }
    
    void update() {
        
    }
    
    const(string)[] mimePaths() const {
        return _mimePaths;
    }
    
    const(MimeType)* mimeType(string name) const {
        return null;
    }
    
    const(MimeType)* mimeTypeForFileName(string fileName) const {
        return null;
    }
    
private:
    const(string)[] _mimePaths;
}

