// SyncFileStreams.swift

import Dispatch
import FoundationExtension

public protocol SyncWriteFileStream: Sendable {

    /// Write data to file or stream
    func write(_ data: some DataProtocol) throws

    func close() throws
}

#if !canImport(FoundationEssentials)

// If we see `FoundationEssentials` it means, we are in oss toolchain. Lets avoid full Foundation dependency

extension FileHandle: SyncWriteFileStream {
    public func write(_ data: some DataProtocol) throws {
        try self.write(contentsOf: data)
    }
}

#else // !canImport(FoundationEssentials)

#if canImport(Android)
import Android
private func platform_open(_ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t = 0) -> Int32 {
    Android.open(path, oflag, mode)
}
private let platform_write   = Android.write
private let platform_close   = Android.close
private let platform_strerror = Android.strerror
#elseif canImport(Glibc)
import Glibc
private func platform_open(_ path: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t = 0) -> Int32 {
    Glibc.open(path, oflag, mode)
}
private let platform_write   = Glibc.write
private let platform_close   = Glibc.close
private let platform_strerror = Glibc.strerror
#endif

#if os(Android) || os(Linux)

import FoundationEssentials
import Synchronization

public final class POSIXWriteFileStream: SyncWriteFileStream, Sendable {
    public init(url: URL) throws {
        let fd = platform_open(url.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else {
            throw SimpleError("Unable to open file for writing: \(url.path)")
        }
        self.state = Mutex(fd)
    }

    deinit {
        state.withLock { fd in
            if fd >= 0 {
                _ = platform_close(fd)
            }
        }
    }

    public func write(_ data: some DataProtocol) throws {
        let bytes = Array(data)
        try state.withLock { fd in
            guard fd >= 0 else {
                throw SimpleError("Write to closed file stream")
            }
            var totalWritten = 0
            while totalWritten < bytes.count {
                let written = bytes.withUnsafeBufferPointer { buf in
                    platform_write(fd, buf.baseAddress! + totalWritten, bytes.count - totalWritten)
                }
                if written < 0 {
                    throw SimpleError("Write failed: \(String(cString: platform_strerror(errno)!))")
                }
                totalWritten += written
            }
        }
    }

    public func close() throws {
        try state.withLock { fd in
            guard fd >= 0 else { return }
            if platform_close(fd) != 0 {
                throw SimpleError("Close failed: \(String(cString: platform_strerror(errno)!))")
            }
            fd = -1
        }
    }

    private let state: Mutex<Int32>
}

#endif // os(Android) || os(Linux)

#endif // !canImport(FoundationEssentials)
