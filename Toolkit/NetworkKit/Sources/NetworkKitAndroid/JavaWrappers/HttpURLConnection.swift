#if canImport(Android)

import CSwiftJavaJNI
import JavaIO
import JavaNet
import SwiftJava

@JavaClass("java.net.HttpURLConnection", extends: URLConnection.self)
public struct HttpURLConnection {
    @JavaMethod
    public func setRequestMethod(_ arg0: String)

    @JavaMethod
    public func getRequestMethod() -> String

    @JavaMethod
    public func getResponseCode() throws -> Int32

    @JavaMethod
    public func getResponseMessage() -> String

    @JavaMethod
    public func getErrorStream() -> InputStream?

    @JavaMethod
    public func disconnect()

    @JavaMethod
    public func setInstanceFollowRedirects(_ arg0: Bool)
}

#endif
