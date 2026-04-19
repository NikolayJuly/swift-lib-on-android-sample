#if canImport(Android)

import CSwiftJavaJNI
import JavaNet
import SwiftJava

extension JavaNet.URL {
    @JavaMethod
    public func openConnection() throws -> URLConnection?
}

#endif
