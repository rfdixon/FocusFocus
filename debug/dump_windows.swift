import Cocoa

let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]

for info in windowInfoList {
    let layer = info[kCGWindowLayer as String] as? Int ?? -1
    let owner = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
    let boundsDict = info[kCGWindowBounds as String] as! [String: Any]
    let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)!
    
    print("Layer: \(layer) | Owner: \(owner) | Bounds: \(bounds)")
}
