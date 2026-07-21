import Cocoa
import Foundation
import Combine

class Settings: ObservableObject {
    static let shared = Settings()
    
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
        
        if let data = UserDefaults.standard.data(forKey: "tintColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            self.tintColor = color
        } else {
            self.tintColor = .black
        }
    }
}
