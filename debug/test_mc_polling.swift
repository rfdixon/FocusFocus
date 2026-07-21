import Cocoa

print("Starting 10 second poll. Open and close Mission Control now!")
let end = Date().addingTimeInterval(10)
var seenWindows = Set<String>()

while Date() < end {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]
    
    var currentWindows = Set<String>()
    for info in windowInfoList {
        let owner = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
        if owner == "Dock" {
            let name = info[kCGWindowName as String] as? String ?? "NoName"
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let boundsDict = info[kCGWindowBounds as String] as! [String: Any]
            let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)!
            let desc = "Dock Window - Layer: \(layer), Name: \(name), Bounds: \(bounds)"
            currentWindows.insert(desc)
            if !seenWindows.contains(desc) {
                print("APPEARED: \(desc)")
                seenWindows.insert(desc)
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.2)
}
print("Done polling.")
