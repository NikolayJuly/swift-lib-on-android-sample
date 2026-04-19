// InputStream+Compatible.swift

// `readAllBytes()` and `readNBytes(int)` are Java API 33+, our minSdk is 28.
// These compatible methods use `read()` (single byte, API 1).
// JNI can't return filled byte[] buffers to Swift (copies, not refs),
// so we read one byte at a time. This runs on background threads — perf is fine.

#if os(Android)

import JavaIO

extension InputStream {

    /// Read all remaining bytes from the stream.
    /// Replacement for `readAllBytes()` which requires API 33+.
    package func readAllBytesCompatible() throws -> [Int8] {
        var result = [Int8]()
        while true {
            let byte = try read()
            if byte < 0 {
                break
            }
            result.append(Int8(truncatingIfNeeded: byte))
        }
        return result
    }

    /// Read up to `count` bytes from the stream.
    /// Replacement for `readNBytes(int)` which requires API 33+.
    package func readNBytesCompatible(_ count: Int32) throws -> [Int8] {
        var result = [Int8]()
        for _ in 0..<count {
            let byte = try read()
            if byte < 0 {
                break
            }
            result.append(Int8(truncatingIfNeeded: byte))
        }
        return result
    }
}

#endif // os(Android)
