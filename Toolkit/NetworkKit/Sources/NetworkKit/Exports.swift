@_exported import NetworkKitAPI

#if canImport(Android)
@_exported import NetworkKitAndroid
#else
@_exported import NetworkKitFoundation
#endif
