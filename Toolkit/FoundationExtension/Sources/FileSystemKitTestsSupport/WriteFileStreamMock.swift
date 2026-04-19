// WriteFileStreamMock.swift

import FileSystemKit
import Foundation

// `@unchecked Sendable` here is a lie, but it is much simpler to ignore, because this for tests only
final public class WriteFileStreamMock: SyncWriteFileStream, @unchecked Sendable {

    public var resData = Data()

    public init() {}

    public func write(_ buffer: UnsafeRawBufferPointer, completionQueue: DispatchQueue, completion: @Sendable @escaping (Error?) -> Void){
        defer {
            completionQueue.async {
                completion(nil)
            }
        }
        guard let baseAddress = buffer.baseAddress else {
            return
        }

        let bufferData = Data(bytes: baseAddress, count: buffer.count)
        resData.append(bufferData)
    }

    public func write(_ data: some DataProtocol) throws {
        resData.append(contentsOf: data)
    }

    public func close() throws {}
}
