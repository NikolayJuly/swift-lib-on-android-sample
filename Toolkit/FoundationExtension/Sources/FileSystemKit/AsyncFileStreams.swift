// AsyncFileStreams.swift

import Foundation
import FoundationExtension
import LoggingExtension
import ObjectStorage

#if canImport(Darwin)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
    #if canImport(Glibc)
    @preconcurrency import Glibc
    #elseif canImport(Musl)
    @preconcurrency import Musl
    #elseif canImport(Android)
    @preconcurrency import Android
    #endif
#elseif os(Windows)
import ucrt
import WinSDK
#else
#error("The POSIX system module was unable to identify your C library.")
#endif

public enum AsyncFileStreamError: LocalizedError, CustomStringConvertible {
    case notFileURL(URL)
    case failedToCreateDescriptor(URL)
    case readError(Int32, URL)
    case writeError(Int32, URL)

    public var description: String {
        switch self {
        case let .notFileURL(url):
            "AsyncFileStreamError.notFileURL: \(url) ."
        case let .failedToCreateDescriptor(url):
            "AsyncFileStreamError.failedToCreateDescriptor: \(url) ."
        case let .readError(errorCode, url):
            "AsyncFileStreamError.readError: \(errorCode), \(url) ."
        case let .writeError(errorCode, url):
            "AsyncFileStreamError.writeError: \(errorCode), \(url) ."
        }
    }
}

public protocol AsyncFileStreamMode {
    static var mode: Int32 { get }
    static var ioType: DispatchIO.StreamType { get }
}

extension AsyncFileStreamMode {
    public static var ioType: DispatchIO.StreamType { .stream }
}

public protocol AsyncFileStreamWritableMode: AsyncFileStreamMode {}

public enum AsyncFileStreamWriteMode: AsyncFileStreamWritableMode {
    public static var mode: Int32 { O_WRONLY | O_TRUNC | O_CREAT }
}

/// Opens an existing file for writing without truncation. Suitable for writing at arbitrary offsets.
public enum AsyncFileStreamWriteAtOffsetMode: AsyncFileStreamWritableMode {
    public static var mode: Int32 { O_WRONLY }
    public static var ioType: DispatchIO.StreamType { .random }
}

public enum AsyncFileStreamReadMode: AsyncFileStreamMode {
    public static var mode: Int32 { O_RDONLY }
}

// Most of the code was taken from blog post: https://losingfight.com/blog/2024/04/22/reading-and-writing-files-in-swift-asyncawait/
public struct AsyncFileStream<Mode: AsyncFileStreamMode>: ~Copyable {

    init(url: URL) throws {
        assert(Thread.isMainThread == false, "We do all of this, specifically to avoid main thread. We will work withFS in this init")
        guard url.isFileURL else {
            throw AsyncFileStreamError.notFileURL(url)
        }

        let queue = DispatchQueue(label: "AsyncFileStream")

        let fileDescriptor = open(url.absoluteURL.path, Mode.mode, S_IRUSR | S_IWUSR)

        // Once we start setting properties, we can't throw. So check to see if we need to throw now, then set properties
        if fileDescriptor == -1 {
            throw AsyncFileStreamError.failedToCreateDescriptor(url)
        }

        self.url = url
        self.queue = queue
        self.fileDescriptor = fileDescriptor

        self.io = DispatchIO(type: Mode.ioType,
                             fileDescriptor: fileDescriptor,
                             queue: queue,
                             cleanupHandler: { [fileDescriptor] error in
            if error != 0 {
                Log.shared.record(SimpleError("Looks like DispatchIO failed while working with file \(url)"))
            }

            // Since we opened the file, we need to close it
            closeFileDescriptor(fileDescriptor)
        })
    }

    deinit {
        if !isClosed {
            io.close()
        }
    }

    consuming func close() {
        isClosed = true
        io.close()
    }

    // MARK: Private

    private let url: URL

    private let queue: DispatchQueue
    private let fileDescriptor: Int32
    private let io: DispatchIO
    private var isClosed = false

}

public extension AsyncFileStream where Mode == AsyncFileStreamReadMode {
    func readToEnd() async throws -> DispatchData {
        try await read(upToCount: .max)
    }

    func read(upToCount length: Int) async throws -> DispatchData {
        assert(Thread.isMainThread == false, "We do all of this, specifically to avoid main thread.")

        return try await withCheckedThrowingContinuation { [url] continuation in
            var readData = DispatchData.empty
            io.read(offset: 0, length: length, queue: queue) { done, data, error in
                if let data {
                    readData.append(data)
                }
                guard done else {
                    return
                }

                if error != 0 {
                    continuation.resume(throwing: AsyncFileStreamError.readError(error, url))
                } else {
                    continuation.resume(returning: readData)
                }
            }
        }
    }
}

public extension AsyncFileStream where Mode == AsyncFileStreamWriteMode {
    /// Write data to file from the beginning. Splits into chunks internally.
    func write(_ data: DispatchData, chunkSize: Int = .defaultWriteChunkSize) async throws {
        try await writeSplitting(data: data, baseOffset: 0, chunkSize: chunkSize)
    }
}

public extension AsyncFileStream where Mode == AsyncFileStreamWriteAtOffsetMode {
    /// Write data at a specific byte offset. File must already exist. Splits into chunks internally.
    func write(_ data: DispatchData, at offset: Int, chunkSize: Int = .defaultWriteChunkSize) async throws {
        try await writeSplitting(data: data, baseOffset: offset, chunkSize: chunkSize)
    }
}

extension Int {
    /// Older NAS devices and some SMB (Server Message Block) mounts reject writes larger than ~2 GB
    /// in a single operation. We split every write into chunks of this size to stay within that limit.
    public static let defaultWriteChunkSize: Int = 100 * 1024 * 1024 // 100 MB
}

private extension AsyncFileStream where Mode: AsyncFileStreamWritableMode {
    func writeSplitting(data: DispatchData, baseOffset: Int, chunkSize: Int) async throws {
        let offsets = Array(stride(from: 0, to: data.count, by: chunkSize)) + [data.count]

        let ranges: [Range<Int>] = zip(offsets, offsets.dropFirst())
            .map { start, end in
                start..<end
            }

        for range in ranges {
            let subData = data.subdata(in: range)
            try await writeRawChunk(subData, at: baseOffset + range.lowerBound)
        }
    }

    func writeRawChunk(_ data: DispatchData, at offset: Int) async throws {
        return try await withCheckedThrowingContinuation { [url] continuation in
            io.write(offset: off_t(offset),
                     data: data,
                     queue: queue) { done, _, error in
                guard done else {
                    return
                }

                if error != 0 {
                    continuation.resume(throwing: AsyncFileStreamError.writeError(error, url))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private func closeFileDescriptor(_ fileDescriptor: Int32) -> Void {
    close(fileDescriptor)
}

// Looks like on linux `DispatchData` is not marked as Sendable. But:
// - it looks like it should be.
// - we are using it in private `queue`. Should be fine..
#if os(Linux) || os(Android)
extension DispatchData: @retroactive @unchecked Sendable {}
#endif
