import Cocoa
import CoreGraphics
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    let MAX_LAYERS = 5
    
    // Instead of a flat array, we group by layer.
    // Each LayerGroup holds one DimWindow per screen.
    class LayerGroup {
        let index: Int
        var windowsByScreen: [CGDirectDisplayID: DimWindow] = [:]
        
        init(index: Int) {
            self.index = index
        }
    }
    
    var layerGroups: [LayerGroup] = []
    
    var eventMonitor: Any?
    var updateTimer: Timer?
    var axObservers: [pid_t: AXObserver] = [:]
    var menuController: MenuController!
    var cancellables = Set<AnyCancellable>()
    var lastBoundaryWindowsByScreen: [CGDirectDisplayID: [Int]] = [:]
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuController = MenuController()
        
        // Initialize layer groups
        for i in 0..<MAX_LAYERS {
            layerGroups.append(LayerGroup(index: i))
        }
        
        // Rebuild windows per screen
        rebuildScreenWindows()
        
        // Listen for screen changes
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        
        Settings.shared.$isEnabled.sink { [weak self] isEnabled in
            if isEnabled {
                self?.setupEventMonitors()
                self?.updateDimmer()
            } else {
                self?.teardownEventMonitors()
                self?.hideAllDims()
            }
        }.store(in: &cancellables)
    }
    
    @objc func screenParametersDidChange() {
        rebuildScreenWindows()
    }
    
    func rebuildScreenWindows() {
        // Hide and remove old windows
        for group in layerGroups {
            for dimWin in group.windowsByScreen.values {
                dimWin.orderOut(nil)
            }
            group.windowsByScreen.removeAll()
            
            // Build new windows for current screens
            for screen in NSScreen.screens {
                // Get the direct display ID for this screen
                guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
                let displayID = CGDirectDisplayID(screenNumber.uint32Value)
                
                let dimWin = DimWindow(layerIndex: group.index, screen: screen)
                group.windowsByScreen[displayID] = dimWin
            }
        }
    }
    
    func setupEventMonitors() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        if isTrusted {
            setupAccessibility()
        } else {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
                self?.delayedUpdate()
            }
            
            // Fallback timer to catch windows closing via unmonitored ways or slow animations
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.updateDimmer()
            }
        }
    }
    
    func setupAccessibility() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        for app in NSWorkspace.shared.runningApplications {
            addObserver(for: app)
        }
    }
    
    @objc func appDidLaunch(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            addObserver(for: app)
        }
    }
    
    @objc func appDidTerminate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            removeObserver(for: app.processIdentifier)
        }
    }
    
    func addObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        var observer: AXObserver?
        
        // SAFETY: passUnretained is used intentionally. AppDelegate is a singleton retained by
        // NSApplication.delegate for the entire app lifetime, so it will never be deallocated
        // while AX observers are active. Using passRetained would risk a retain cycle.
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard AXObserverCreate(pid, axObserverCallback, &observer) == .success, let axObserver = observer else {
            return
        }
        
        let element = AXUIElementCreateApplication(pid)
        let notifications: [String] = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification
        ]
        
        for notification in notifications {
            AXObserverAddNotification(axObserver, element, notification as CFString, context)
        }
        
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        axObservers[pid] = axObserver
    }
    
    func removeObserver(for pid: pid_t) {
        if let observer = axObservers[pid] {
            CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(observer), .defaultMode)
            axObservers.removeValue(forKey: pid)
        }
    }
    
    func teardownAccessibility() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.removeObserver(self, name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        for pid in axObservers.keys {
            removeObserver(for: pid)
        }
    }
    
    func teardownEventMonitors() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        ws.removeObserver(self, name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        ws.removeObserver(self, name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        updateTimer?.invalidate()
        updateTimer = nil
        
        teardownAccessibility()
    }
    
    @objc func delayedUpdate() {
        // Add a slight delay to ensure the window server has updated its internal ordering
        // before we query it after a click or app activation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateDimmer()
        }
        // Additional delay to catch window close animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.updateDimmer()
        }
    }
    
    func hideAllDims() {
        for group in layerGroups {
            for dimWin in group.windowsByScreen.values {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.4
                    dimWin.animator().alphaValue = 0.0
                }, completionHandler: {
                    dimWin.orderOut(nil)
                })
            }
        }
    }
    
    @objc func updateDimmer() {
        guard Settings.shared.isEnabled else { return }
        
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }
        
        // Build a screen lookup dictionary once to avoid repeated NSScreen.screens iteration
        var screensByDisplayID: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            screensByDisplayID[displayID] = screen
        }
        
        // CGWindowListCopyWindowInfo returns bounds in CG coordinates (origin at top-left of primary display,
        // Y increases downward). NSScreen.frame uses NS coordinates (origin at bottom-left, Y increases upward).
        // We need the primary screen height to convert between the two systems.
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        
        var boundaryWindowsByScreen: [CGDirectDisplayID: [Int]] = [:]
        var currentPIDByScreen: [CGDirectDisplayID: Int32] = [:]
        var screenIsFullscreen: [CGDirectDisplayID: Bool] = [:]
        
        for displayID in screensByDisplayID.keys {
            boundaryWindowsByScreen[displayID] = []
            screenIsFullscreen[displayID] = false
        }
        
        for info in windowInfoList {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0.1 else { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != ProcessInfo.processInfo.processIdentifier else { continue }
            
            // Check if explicitly marked as not on screen (fixes minimized windows showing up in Dock)
            if let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen {
                continue
            }
            
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            
            guard let windowID = info[kCGWindowNumber as String] as? Int else { continue }
            
            // Ignore tiny invisible/tracking windows (e.g. Chrome's 1x1 windows)
            guard cgBounds.width > 50 && cgBounds.height > 50 else { continue }
            
            // Convert CG bounds to NS coordinates for correct screen matching
            let nsBounds = CGRect(
                x: cgBounds.origin.x,
                y: mainScreenHeight - cgBounds.origin.y - cgBounds.height,
                width: cgBounds.width,
                height: cgBounds.height
            )
            let nsCenter = CGPoint(x: nsBounds.midX, y: nsBounds.midY)
            
            // Find which screen this window's center is on
            var targetDisplayID: CGDirectDisplayID? = nil
            var targetScreen: NSScreen? = nil
            
            for (displayID, screen) in screensByDisplayID {
                if screen.frame.contains(nsCenter) {
                    targetDisplayID = displayID
                    targetScreen = screen
                    break
                }
            }
            
            guard let displayID = targetDisplayID, let screen = targetScreen else { continue }
            
            // Check that window intersects the safe area (not just barely peeking in)
            let safeArea = screen.frame.insetBy(dx: 50, dy: 50)
            guard nsBounds.intersects(safeArea) else { continue }
            
            // Check if this window is fullscreen (covers the entire screen)
            let sizeMatches = abs(nsBounds.width - screen.frame.width) < 2 &&
                              abs(nsBounds.height - screen.frame.height) < 2
            let originMatches = abs(nsBounds.origin.x - screen.frame.origin.x) < 2 &&
                                abs(nsBounds.origin.y - screen.frame.origin.y) < 2
            if sizeMatches && originMatches {
                screenIsFullscreen[displayID] = true
            }
            
            var boundaries = boundaryWindowsByScreen[displayID] ?? []
            if boundaries.count >= MAX_LAYERS { continue }
            
            let currentPID = currentPIDByScreen[displayID]
            
            if currentPID == nil {
                currentPIDByScreen[displayID] = ownerPID
                boundaries.append(windowID)
                boundaryWindowsByScreen[displayID] = boundaries
            } else if ownerPID != currentPID {
                currentPIDByScreen[displayID] = ownerPID
                boundaries.append(windowID)
                boundaryWindowsByScreen[displayID] = boundaries
            }
        }
        
        if boundaryWindowsByScreen == lastBoundaryWindowsByScreen { return }
        lastBoundaryWindowsByScreen = boundaryWindowsByScreen
        
        for group in layerGroups {
            for (displayID, dimWin) in group.windowsByScreen {
                let boundaries = boundaryWindowsByScreen[displayID] ?? []
                
                let isFullscreen = screenIsFullscreen[displayID] ?? false
                
                if !isFullscreen && group.index < boundaries.count {
                    let targetWindowID = boundaries[group.index]
                    dimWin.order(.below, relativeTo: targetWindowID)
                    
                    if dimWin.alphaValue == 0 {
                        dimWin.alphaValue = 1.0
                    }
                } else {
                    if dimWin.alphaValue > 0 {
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.4
                            dimWin.animator().alphaValue = 0.0
                        }, completionHandler: {
                            dimWin.orderOut(nil)
                        })
                    }
                }
            }
        }
    }
}

func axObserverCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
    appDelegate.delayedUpdate()
}
