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
    var isAccessibilityActive: Bool = false
    var menuController: MenuController!
    var cancellables = Set<AnyCancellable>()
    var lastBoundaryWindowsByScreen: [CGDirectDisplayID: [Int]] = [:]
    var isStageManagerPaused: Bool = false
    var stageManagerCheckTimer: Timer?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuController = MenuController()
        
        // Initialize layer groups
        for i in 0..<MAX_LAYERS {
            layerGroups.append(LayerGroup(index: i))
        }
        
        // Rebuild windows per screen
        rebuildScreenWindows()
        
        // Listen for screen changes and system/display wake
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenOrSystemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenOrSystemDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        
        // Listen for app becoming active to check if accessibility was granted in System Settings
        NotificationCenter.default.addObserver(self, selector: #selector(checkAccessibilityUpgrade), name: NSApplication.didBecomeActiveNotification, object: nil)
        
        // Connect centralized WallpaperManager
        WallpaperManager.shared.onWallpaperChange = { [weak self] in
            guard let self = self else { return }
            for group in self.layerGroups {
                for dimWin in group.windowsByScreen.values {
                    dimWin.updateWallpaperImage()
                }
            }
        }
        
        Settings.shared.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.lastBoundaryWindowsByScreen.removeAll()
                    self?.setupEventMonitors()
                    self?.updateDimmer()
                    self?.delayedUpdate()
                } else {
                    self?.teardownEventMonitors()
                    self?.hideAllDims()
                }
            }.store(in: &cancellables)
        
        Settings.shared.$focusMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastBoundaryWindowsByScreen.removeAll()
                self?.updateDimmer()
            }.store(in: &cancellables)
            
        Settings.shared.$pauseInStageManager
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateStageManagerState()
            }.store(in: &cancellables)
            
        stageManagerCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.evaluateStageManagerState()
        }
        
        setupDarwinNotifications()
        evaluateStageManagerState()
    }
    
    @objc func screenOrSystemDidWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.rebuildScreenWindows()
            self?.lastBoundaryWindowsByScreen.removeAll()
            self?.updateDimmer()
            WallpaperManager.shared.refreshAll()
        }
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
        // Zero-permission check: DO NOT prompt the user on launch!
        let isTrusted = AXIsProcessTrusted()
        
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didHideApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(delayedUpdate), name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        
        if isTrusted {
            setupAccessibility()
        } else {
            setupFallbackMonitors()
        }
    }
    
    func setupFallbackMonitors() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
                self?.delayedUpdate()
            }
        }
        
        // Gentle fallback timer to catch keyboard window navigation (Cmd+`) or window close
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.updateDimmer()
            }
        }
    }
    
    func teardownFallbackMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc func checkAccessibilityUpgrade() {
        guard Settings.shared.isEnabled else { return }
        if !isAccessibilityActive && AXIsProcessTrusted() {
            teardownFallbackMonitors()
            setupAccessibility()
            updateDimmer()
        }
    }
    
    func setupAccessibility() {
        guard !isAccessibilityActive else { return }
        isAccessibilityActive = true
        
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appDidLaunch(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        // Fast-path: immediately attach to the frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.activationPolicy == .regular {
            addObserver(for: frontApp)
        }
        
        // Background-queue regular apps to prevent any unresponsive app from blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let regularApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            DispatchQueue.main.async {
                guard let self = self, self.isAccessibilityActive else { return }
                for app in regularApps {
                    self.addObserver(for: app)
                }
            }
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
        // ONLY observe regular GUI applications that have windows (skip daemons, background services, etc.)
        guard app.activationPolicy == .regular else { return }
        let pid = app.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else { return }
        guard axObservers[pid] == nil else { return }
        
        var observer: AXObserver?
        
        // SAFETY: passUnretained is used intentionally. AppDelegate is a singleton retained by
        // NSApplication.delegate for the entire app lifetime, so it will never be deallocated
        // while AX observers are active. Using passRetained would risk a retain cycle.
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard AXObserverCreate(pid, axObserverCallback, &observer) == .success, let axObserver = observer else {
            return
        }
        
        let element = AXUIElementCreateApplication(pid)
        // Prevent any slow or paused process from blocking the runloop during IPC
        AXUIElementSetMessagingTimeout(element, 0.15)
        
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
        isAccessibilityActive = false
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
        ws.removeObserver(self, name: NSWorkspace.didHideApplicationNotification, object: nil)
        ws.removeObserver(self, name: NSWorkspace.didUnhideApplicationNotification, object: nil)
        
        teardownFallbackMonitors()
        
        pendingUpdateWorkItem?.cancel()
        pendingUpdateWorkItem = nil
        pendingFollowUpWorkItem?.cancel()
        pendingFollowUpWorkItem = nil
        
        teardownAccessibility()
    }
    
    private var pendingUpdateWorkItem: DispatchWorkItem?
    private var pendingFollowUpWorkItem: DispatchWorkItem?
    
    @objc func delayedUpdate() {
        // Coalesce and debounce rapid notifications (e.g. window move/resize events)
        pendingUpdateWorkItem?.cancel()
        pendingFollowUpWorkItem?.cancel()
        
        // Fast-path: 50ms coalesce for immediate responsiveness
        let primaryItem = DispatchWorkItem { [weak self] in
            self?.updateDimmer()
        }
        pendingUpdateWorkItem = primaryItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: primaryItem)
        
        // Follow-up: 350ms to catch window close animations
        let followUpItem = DispatchWorkItem { [weak self] in
            self?.updateDimmer()
        }
        pendingFollowUpWorkItem = followUpItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: followUpItem)
    }
    
    static func isStageManagerActive() -> Bool {
        CFPreferencesAppSynchronize("com.apple.WindowManager" as CFString)
        guard let val = CFPreferencesCopyAppValue("GloballyEnabled" as CFString, "com.apple.WindowManager" as CFString) else {
            return false
        }
        if CFGetTypeID(val) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((val as! CFBoolean))
        }
        if let num = val as? NSNumber {
            return num.boolValue
        }
        return false
    }
    
    @discardableResult
    func evaluateStageManagerState() -> Bool {
        let isSM = AppDelegate.isStageManagerActive()
        let shouldPause = Settings.shared.isEnabled && Settings.shared.pauseInStageManager && isSM
        
        if shouldPause != isStageManagerPaused {
            isStageManagerPaused = shouldPause
            menuController?.setStageManagerPaused(shouldPause)
            
            if shouldPause {
                hideAllDims()
            } else if Settings.shared.isEnabled {
                lastBoundaryWindowsByScreen.removeAll()
                updateDimmer()
            }
        }
        
        return shouldPause
    }
    
    private func setupDarwinNotifications() {
        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let smCallback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer = observer else { return }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                appDelegate.evaluateStageManagerState()
            }
        }
        let observerPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(darwinCenter, observerPtr, smCallback, "com.apple.WindowManager.GloballyEnabled" as CFString, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(darwinCenter, observerPtr, smCallback, "com.apple.WindowManager.settings-changed" as CFString, nil, .deliverImmediately)
    }
    
    func hideAllDims() {
        lastBoundaryWindowsByScreen.removeAll()
        for group in layerGroups {
            for dimWin in group.windowsByScreen.values {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    dimWin.animator().alphaValue = 0.0
                }, completionHandler: { [weak self] in
                    if !Settings.shared.isEnabled || self?.isStageManagerPaused == true {
                        dimWin.orderOut(nil)
                    }
                })
            }
        }
    }
    
    @objc func updateDimmer() {
        guard Settings.shared.isEnabled else { return }
        if evaluateStageManagerState() { return }
        
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
        
        struct ScreenWindowInfo {
            let windowID: Int
            let ownerPID: Int32
        }
        
        var visibleWindowsByScreen: [CGDirectDisplayID: [ScreenWindowInfo]] = [:]
        var screenIsFullscreen: [CGDirectDisplayID: Bool] = [:]
        
        for displayID in screensByDisplayID.keys {
            visibleWindowsByScreen[displayID] = []
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
            
            visibleWindowsByScreen[displayID]?.append(ScreenWindowInfo(windowID: windowID, ownerPID: ownerPID))
        }
        
        var boundaryWindowsByScreen: [CGDirectDisplayID: [Int]] = [:]
        let focusMode = Settings.shared.focusMode
        
        for (displayID, windows) in visibleWindowsByScreen {
            var boundaries: [Int] = []
            
            if focusMode == .singleWindow {
                // Focus Active Window: Every window in the z-stack is its own depth tier
                for w in windows {
                    if boundaries.count >= MAX_LAYERS { break }
                    boundaries.append(w.windowID)
                }
            } else {
                // Focus Entire App: All windows belonging to the same app share a tier;
                // the dimmer is placed below the LAST window of that app.
                var i = 0
                while i < windows.count && boundaries.count < MAX_LAYERS {
                    let currentPID = windows[i].ownerPID
                    var lastWindowOfApp = windows[i].windowID
                    while i < windows.count && windows[i].ownerPID == currentPID {
                        lastWindowOfApp = windows[i].windowID
                        i += 1
                    }
                    boundaries.append(lastWindowOfApp)
                }
            }
            boundaryWindowsByScreen[displayID] = boundaries
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
                    
                    if dimWin.alphaValue < 1.0 {
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.2
                            dimWin.animator().alphaValue = 1.0
                        }
                    }
                } else {
                    if dimWin.alphaValue > 0 {
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.3
                            dimWin.animator().alphaValue = 0.0
                        }, completionHandler: { [weak self] in
                            if !Settings.shared.isEnabled || self?.isStageManagerPaused == true || group.index >= (self?.lastBoundaryWindowsByScreen[displayID]?.count ?? 0) {
                                dimWin.orderOut(nil)
                            }
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
