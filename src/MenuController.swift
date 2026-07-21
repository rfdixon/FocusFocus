import Cocoa
import SwiftUI

class MenuController: NSObject, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var preferencesWindow: NSWindow?
    
    override init() {
        super.init()
        setupMenu()
    }
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // SF Symbol "square.3.layers.3d.down.backward" looks like a stack of windows
            button.image = NSImage(systemSymbolName: "square.3.layers.3d.down.backward", accessibilityDescription: "FocusFocus")
        }
        
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
    
    @objc func toggleDimming(_ sender: NSMenuItem) {
        Settings.shared.isEnabled.toggle()
        sender.state = Settings.shared.isEnabled ? .on : .off
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
