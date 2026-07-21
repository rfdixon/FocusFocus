import Cocoa

let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]

print("Dumping all Dock windows:")
for info in windowInfoList {
    let layer = info[kCGWindowLayer as String] as? Int ?? -1
    let owner = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
    let name = info[kCGWindowName as String] as? String ?? "No Name"
    if owner == "Dock" {
        print("Layer: \(layer) | Owner: \(owner) | Name: \(name)")
    }
}
