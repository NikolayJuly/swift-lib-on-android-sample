// UIDeviceExtension.swift

#if os(iOS)
import Foundation

import UIKit


public extension UIDevice {

    @nonobjc nonisolated
    static var modelRawName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") {
            identifier, element in
            guard let value = element.value as? Int8 , value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }

}
#endif // os(iOS)
