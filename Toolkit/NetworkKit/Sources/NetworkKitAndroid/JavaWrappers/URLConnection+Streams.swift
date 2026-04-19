#if canImport(Android)

import CSwiftJavaJNI
import JavaIO
import JavaNet
import SwiftJava

extension URLConnection {
    @JavaMethod
    public func getInputStream() throws -> InputStream?

    @JavaMethod
    public func getOutputStream() throws -> OutputStream?
}

#endif
