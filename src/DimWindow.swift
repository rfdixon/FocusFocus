import Cocoa
import QuartzCore
import Combine

class DimWindow: NSWindow {
    var cancellables = Set<AnyCancellable>()
    var wallpaperCheckTimer: Timer?
    var currentWallpaperURL: URL?
    let layerIndex: Int
    let screenRef: NSScreen
    
    let tintView = NSView()
    let wallpaperView = NSImageView()
    
    init(layerIndex: Int, screen: NSScreen) {
        self.layerIndex = layerIndex
        self.screenRef = screen
        
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.alphaValue = 0.0 // Managed by fade-in animation
        self.backgroundColor = .clear 
        
        let container = NSView()
        self.contentView = container
        
        // Setup Wallpaper View
        wallpaperView.imageScaling = .scaleAxesIndependently 
        wallpaperView.autoresizingMask = [.width, .height]
        wallpaperView.frame = container.bounds
        wallpaperView.isHidden = true
        
        if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
            currentWallpaperURL = url
            if let image = NSImage(contentsOf: url) {
                wallpaperView.image = image
            }
        }
        
        container.addSubview(wallpaperView)
        
        // Refresh wallpaper when the user switches Spaces (wallpaper can differ per space)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshWallpaper),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Fast-path: Some older macOS versions fire this when wallpaper changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(refreshWallpaper),
            name: NSNotification.Name("com.apple.desktop"),
            object: nil
        )
        
        // Reliable-path: Poll for wallpaper changes (macOS does not provide a reliable notification)
        wallpaperCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshWallpaper()
        }
        
        // Setup Tint View
        tintView.wantsLayer = true
        tintView.autoresizingMask = [.width, .height]
        tintView.frame = container.bounds
        container.addSubview(tintView)
        
        Publishers.CombineLatest4(
            Settings.shared.$baseDarkness,
            Settings.shared.$depthMultiplier,
            Settings.shared.$tintColor,
            Settings.shared.$fadeIntoDesktop
        ).sink { [weak self] (base, multiplier, color, fade) in
            guard let self = self else { return }
            
            let rawAlpha = base + (Double(self.layerIndex) * multiplier)
            let clampedAlpha = min(max(rawAlpha, 0.0), 1.0)
            
            if fade {
                self.wallpaperView.isHidden = false
                self.wallpaperView.alphaValue = CGFloat(clampedAlpha)
                self.tintView.layer?.backgroundColor = NSColor.clear.cgColor
            } else {
                self.wallpaperView.isHidden = true
                self.tintView.layer?.backgroundColor = color.withAlphaComponent(CGFloat(clampedAlpha)).cgColor
            }
        }.store(in: &cancellables)
    }
    
    @objc func refreshWallpaper() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let url = NSWorkspace.shared.desktopImageURL(for: self.screenRef) {
                if url != self.currentWallpaperURL {
                    self.currentWallpaperURL = url
                    if let image = NSImage(contentsOf: url) {
                        self.wallpaperView.image = image
                    }
                }
            }
        }
    }
    
    deinit {
        wallpaperCheckTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
