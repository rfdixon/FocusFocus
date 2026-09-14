import Cocoa
import Combine

final class WallpaperManager {
    static let shared = WallpaperManager()
    
    private var imageCache: [URL: NSImage] = [:]
    private var currentWallpaperURLs: [CGDirectDisplayID: URL] = [:]
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    var onWallpaperChange: (() -> Void)?
    
    private init() {
        // Space changes: user can have different wallpapers on different spaces
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Listen to fadeIntoDesktop: ONLY run background checks and maintain cache when active
        Settings.shared.$fadeIntoDesktop
            .receive(on: RunLoop.main)
            .sink { [weak self] isFade in
                guard let self = self else { return }
                if isFade {
                    self.refreshAll()
                    self.startPollTimer()
                } else {
                    self.stopPollTimer()
                    self.imageCache.removeAll()
                    self.currentWallpaperURLs.removeAll()
                }
            }
            .store(in: &cancellables)
    }
    
    func image(for screen: NSScreen) -> NSImage? {
        guard Settings.shared.fadeIntoDesktop else { return nil }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        
        if let cached = imageCache[url] {
            return cached
        }
        
        if let img = NSImage(contentsOf: url) {
            imageCache[url] = img
            return img
        }
        
        return nil
    }
    
    @objc private func handleSpaceOrScreenChange() {
        guard Settings.shared.fadeIntoDesktop else { return }
        refreshAll()
    }
    
    func refreshAll() {
        guard Settings.shared.fadeIntoDesktop else { return }
        var didChange = false
        
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                let previousURL = currentWallpaperURLs[displayID]
                if previousURL != url || imageCache[url] == nil {
                    currentWallpaperURLs[displayID] = url
                    if let img = NSImage(contentsOf: url) {
                        imageCache[url] = img
                        didChange = true
                    }
                }
            }
        }
        
        if didChange {
            onWallpaperChange?()
        }
    }
    
    private func startPollTimer() {
        stopPollTimer()
        // Single coalesced timer at relaxed 5-second interval instead of 15 timers at 1 second
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }
    
    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
