import Cocoa
import QuartzCore
import Combine

class DimWindow: NSWindow {
    var cancellables = Set<AnyCancellable>()
    let layerIndex: Int
    let screenRef: NSScreen
    
    let tintView = NSView()
    let wallpaperView = NSImageView()
    
    init(layerIndex: Int, screen: NSScreen) {
        self.layerIndex = layerIndex
        self.screenRef = screen
        
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: true)
        
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        self.alphaValue = 0.0 // Managed by fade-in animation
        self.backgroundColor = .clear 
        
        let container = NSView()
        self.contentView = container
        
        // Setup Wallpaper View (layer-backed for GPU compositing)
        wallpaperView.wantsLayer = true
        wallpaperView.imageScaling = .scaleAxesIndependently 
        wallpaperView.autoresizingMask = [.width, .height]
        wallpaperView.frame = container.bounds
        wallpaperView.isHidden = true
        container.addSubview(wallpaperView)
        
        // Setup Tint View (layer-backed for GPU compositing)
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
                if self.wallpaperView.image == nil {
                    self.wallpaperView.image = WallpaperManager.shared.image(for: self.screenRef)
                }
                self.wallpaperView.isHidden = false
                self.wallpaperView.alphaValue = CGFloat(clampedAlpha)
                self.tintView.layer?.backgroundColor = NSColor.clear.cgColor
            } else {
                self.wallpaperView.isHidden = true
                self.wallpaperView.image = nil // Free reference when fade is disabled
                self.tintView.layer?.backgroundColor = color.withAlphaComponent(CGFloat(clampedAlpha)).cgColor
            }
        }.store(in: &cancellables)
    }
    
    func updateWallpaperImage() {
        if Settings.shared.fadeIntoDesktop {
            self.wallpaperView.image = WallpaperManager.shared.image(for: self.screenRef)
        } else {
            self.wallpaperView.image = nil
        }
    }
}
