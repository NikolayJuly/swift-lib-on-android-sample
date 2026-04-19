// MainQueueDraining.swift

#if os(Android)

import CSwiftJavaJNI

/// Drains Swift's libdispatch main queue once.
///
/// On Android, libdispatch's main queue is NOT automatically serviced.
/// This function must be called periodically (via a drain loop) from the
/// Android Main (UI) thread to process `Task { @MainActor in }`, timers,
/// and `DispatchQueue.main.async` blocks.
///
/// **CRITICAL — Thread binding:**
/// libdispatch binds its main queue to the first thread that drains it.
/// The very first call to this function determines which thread "owns" the
/// main queue. All subsequent calls MUST come from the same thread,
/// otherwise libdispatch crashes with `brk #0x1` inside
/// `_dispatch_main_queue_callback_4CF`.
///
/// On the Kotlin side, `SwiftRuntime` ensures:
/// 1. `libdispatch.so` is loaded on the Main thread (global constructors run there)
/// 2. The first drain call happens on the Main thread (binding it)
/// 3. The drain loop continues on the Main thread via `Handler(Looper.getMainLooper())`
@_cdecl("Java_com_sample_swift_runtime_MainQueueDrainer_nativeDrainMainQueue")
public func MainQueueDrainer_nativeDrainMainQueue(environment: UnsafeMutablePointer<JNIEnv?>!,
                                                  thisObj: jobject) {
    _dispatch_main_queue_callback_4CF(nil)
}

/// Private libdispatch entrypoint that drains the main queue once.
@_silgen_name("_dispatch_main_queue_callback_4CF")
private func _dispatch_main_queue_callback_4CF(_ msg: UnsafeMutableRawPointer?)

#endif // os(Android)
