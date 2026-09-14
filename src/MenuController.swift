import Cocoa
import SwiftUI
import Combine

class MenuController: NSObject, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupMenu()
        
        Settings.shared.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                self?.updateIcon(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(isEnabled: Settings.shared.isEnabled)
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Enable Dimming", action: #selector(toggleDimming(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = Settings.shared.isEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefItem.target = self
        menu.addItem(prefItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit FocusFocus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func updateIcon(isEnabled: Bool) {
        if let button = statusItem.button {
            button.image = MenuController.createMenuBarIcon(enabled: isEnabled)
        }
        if let toggleItem = statusItem.menu?.items.first {
            toggleItem.state = isEnabled ? .on : .off
        }
    }
    
    static func createMenuBarIcon(enabled: Bool = true) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            
            let baseColor = NSColor.black
            
            // 1. Window Outline
            let windowRect = CGRect(x: 1.25, y: 1.5, width: 15.5, height: 15.0)
            let windowPath = CGPath(roundedRect: windowRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            ctx.addPath(windowPath)
            ctx.setLineWidth(1.25)
            ctx.setStrokeColor(baseColor.cgColor)
            ctx.strokePath()
            
            // 2. Traffic Light Dots
            let dotY: CGFloat = 4.2
            let dotRadius: CGFloat = 0.75
            let dotXCoords: [CGFloat] = [3.7, 5.9, 8.1]
            ctx.setFillColor(baseColor.cgColor)
            for dx in dotXCoords {
                ctx.fillEllipse(in: CGRect(x: dx - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
            
            // 3. Titlebar separator rule
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(0.6)
            ctx.strokeLineSegments(between: [CGPoint(x: 1.25, y: 6.3), CGPoint(x: 16.75, y: 6.3)])
            
            // 4. FocusFocus "Ff" Logotype
            ctx.saveGState()
            ctx.translateBy(x: 4.4, y: 7.2)
            ctx.scaleBy(x: 0.0846, y: 0.0846)
            ctx.addPath(buildFfPath())
            ctx.setFillColor(baseColor.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            
            return true
        }
        image.isTemplate = true
        return image
    }
    
    private static func buildFfPath() -> CGPath {
        let path = CGMutablePath()
        
        // Capital 'F'
        path.move(to: CGPoint(x: 21.58, y: 22.84))
        path.addLine(to: CGPoint(x: 21.58, y: 47.57))
        path.addLine(to: CGPoint(x: 48.12, y: 47.57))
        path.addLine(to: CGPoint(x: 48.12, y: 64.06))
        path.addLine(to: CGPoint(x: 21.58, y: 64.06))
        path.addLine(to: CGPoint(x: 21.58, y: 95.15))
        path.addLine(to: CGPoint(x: 0.0, y: 95.15))
        path.addLine(to: CGPoint(x: 0.0, y: 6.34))
        path.addLine(to: CGPoint(x: 53.85, y: 6.34))
        path.addLine(to: CGPoint(x: 53.85, y: 22.84))
        path.addLine(to: CGPoint(x: 21.58, y: 22.84))
        path.closeSubpath()
        
        // Lowercase 'f'
        path.move(to: CGPoint(x: 85.34, y: 28.42))
        path.addLine(to: CGPoint(x: 103.73, y: 28.42))
        path.addLine(to: CGPoint(x: 103.95, y: 43.65))
        path.addLine(to: CGPoint(x: 85.88, y: 43.65))
        path.addLine(to: CGPoint(x: 85.88, y: 95.16))
        path.addLine(to: CGPoint(x: 65.09, y: 95.16))
        path.addLine(to: CGPoint(x: 65.09, y: 43.65))
        path.addLine(to: CGPoint(x: 54.45, y: 43.65))
        path.addLine(to: CGPoint(x: 54.27, y: 28.42))
        path.addLine(to: CGPoint(x: 65.09, y: 28.42))
        path.addLine(to: CGPoint(x: 65.09, y: 25.38))
        path.addCurve(to: CGPoint(x: 92.80, y: 0.0), control1: CGPoint(x: 65.09, y: 10.03), control2: CGPoint(x: 74.95, y: 0.0))
        path.addCurve(to: CGPoint(x: 108.66, y: 3.68), control1: CGPoint(x: 98.66, y: 0.0), control2: CGPoint(x: 104.79, y: 1.14))
        path.addLine(to: CGPoint(x: 103.20, y: 18.02))
        path.addCurve(to: CGPoint(x: 94.80, y: 15.61), control1: CGPoint(x: 100.94, y: 16.50), control2: CGPoint(x: 98.00, y: 15.61))
        path.addCurve(to: CGPoint(x: 85.34, y: 25.51), control1: CGPoint(x: 88.67, y: 15.61), control2: CGPoint(x: 85.34, y: 18.78))
        path.addLine(to: CGPoint(x: 85.34, y: 28.43))
        path.closeSubpath()
        
        return path
    }
    
    @objc func toggleDimming(_ sender: NSMenuItem) {
        Settings.shared.isEnabled.toggle()
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            let prefView = PreferencesView()
            let hostingController = NSHostingController(rootView: prefView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.center()
            window.delegate = self
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        preferencesWindow = nil
    }
}
