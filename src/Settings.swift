import Cocoa
import Foundation
import Combine

enum FocusMode: String, CaseIterable, Identifiable {
    case singleWindow = "singleWindow"
    case singleApp = "singleApp"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .singleWindow: return "Active Window"
        case .singleApp: return "Entire App"
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()
    
    @Published var focusMode: FocusMode {
        didSet { UserDefaults.standard.set(focusMode.rawValue, forKey: "focusMode") }
    }
    
    @Published var baseDarkness: Double {
        didSet { UserDefaults.standard.set(baseDarkness, forKey: "baseDarkness") }
    }
    
    @Published var depthMultiplier: Double {
        didSet { UserDefaults.standard.set(depthMultiplier, forKey: "depthMultiplier") }
    }
    
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }
    
    @Published var fadeIntoDesktop: Bool {
        didSet { UserDefaults.standard.set(fadeIntoDesktop, forKey: "fadeIntoDesktop") }
    }
    
    @Published var pauseInStageManager: Bool {
        didSet { UserDefaults.standard.set(pauseInStageManager, forKey: "pauseInStageManager") }
    }
    
    @Published var tintColor: NSColor {
        didSet {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: tintColor, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: "tintColor")
            }
        }
    }
    
    // NOTE: Swift does not fire `didSet` for property assignments during `init`, so the
    // UserDefaults writes in each `didSet` will only trigger on subsequent user changes,
    // not during initial load from UserDefaults here.
    private init() {
        if let modeRaw = UserDefaults.standard.string(forKey: "focusMode"),
           let mode = FocusMode(rawValue: modeRaw) {
            self.focusMode = mode
        } else {
            self.focusMode = .singleWindow
        }
        
        if UserDefaults.standard.object(forKey: "baseDarkness") == nil {
            UserDefaults.standard.set(0.15, forKey: "baseDarkness")
        }
        self.baseDarkness = UserDefaults.standard.double(forKey: "baseDarkness")
        
        if UserDefaults.standard.object(forKey: "depthMultiplier") == nil {
            UserDefaults.standard.set(0.05, forKey: "depthMultiplier")
        }
        self.depthMultiplier = UserDefaults.standard.double(forKey: "depthMultiplier")
        
        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isEnabled")
        }
        self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        
        if UserDefaults.standard.object(forKey: "fadeIntoDesktop") == nil {
            UserDefaults.standard.set(false, forKey: "fadeIntoDesktop")
        }
        self.fadeIntoDesktop = UserDefaults.standard.bool(forKey: "fadeIntoDesktop")
        
        if UserDefaults.standard.object(forKey: "pauseInStageManager") == nil {
            UserDefaults.standard.set(true, forKey: "pauseInStageManager")
        }
        self.pauseInStageManager = UserDefaults.standard.bool(forKey: "pauseInStageManager")
        
        if let data = UserDefaults.standard.data(forKey: "tintColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            self.tintColor = color
        } else {
            self.tintColor = .black
        }
    }
}
