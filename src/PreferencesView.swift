import SwiftUI
import AppKit

struct ColorWellView: NSViewRepresentable {
    @Binding var color: NSColor
    
    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.color = color
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorDidChange(_:))
        return well
    }
    
    func updateNSView(_ well: NSColorWell, context: Context) {
        if well.color != color {
            well.color = color
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ColorWellView
        init(_ parent: ColorWellView) {
            self.parent = parent
        }
        
        @objc func colorDidChange(_ sender: NSColorWell) {
            parent.color = sender.color
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var settings = Settings.shared
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    
    private let labelWidth: CGFloat = 115
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. General
            HStack(alignment: .top, spacing: 14) {
                Text("General:")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Enable Dimming", isOn: $settings.isEnabled)
                            .toggleStyle(.checkbox)
                        Text("Darkens background and inactive windows on macOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 18)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Fade into Desktop", isOn: $settings.fadeIntoDesktop)
                            .toggleStyle(.checkbox)
                        Text("Blends background layers into your wallpaper instead of a solid tint.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 18)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Pause when Stage Manager is active", isOn: $settings.pauseInStageManager)
                            .toggleStyle(.checkbox)
                        Text("Automatically pauses dimming while Stage Manager is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 18)
                    }
                }
                Spacer()
            }
            
            // 2. Focus Scope
            HStack(alignment: .top, spacing: 14) {
                Text("Focus Scope:")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 5) {
                    Picker("", selection: $settings.focusMode) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    
                    Text(settings.focusMode == .singleWindow 
                        ? "Only the frontmost window stays bright; all other windows are dimmed."
                        : "All windows belonging to the active application stay bright together.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            
            // 3. Appearance
            HStack(alignment: .top, spacing: 14) {
                Text("Appearance:")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Tint Color with native NSColorWell and clickable label
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Button(action: openColorPanel) {
                                Text("Tint Color:")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            
                            ColorWellView(color: $settings.tintColor)
                                .frame(width: 44, height: 24)
                        }
                        
                        if settings.fadeIntoDesktop {
                            Text("Note: Tint Color is inactive while \"Fade into Desktop\" is enabled.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Base Darkness
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Base Darkness:")
                                .font(.body)
                                .frame(width: 110, alignment: .leading)
                            Slider(value: $settings.baseDarkness, in: 0.0...0.8, step: 0.01)
                                .frame(width: 150)
                            Text("\(Int(settings.baseDarkness * 100))%")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .frame(width: 38, alignment: .trailing)
                        }
                        Text("Controls the darkness of the first background layer.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Depth Multiplier
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Depth Multiplier:")
                                .font(.body)
                                .frame(width: 110, alignment: .leading)
                            Slider(value: $settings.depthMultiplier, in: 0.0...0.3, step: 0.01)
                                .frame(width: 150)
                            Text("\(Int(settings.depthMultiplier * 100))%")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                                .frame(width: 38, alignment: .trailing)
                        }
                        Text("Darkens each successive layer to exaggerate depth.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // 4. Tracking (Permissions)
            HStack(alignment: .top, spacing: 14) {
                Text("Tracking:")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.top, 1)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isAccessibilityTrusted ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                            Text(isAccessibilityTrusted ? "Live Drag Tracking Active" : "Not Enabled")
                                .font(.body)
                        }
                        Text(isAccessibilityTrusted
                            ? "Real-time window tracking while dragging is active via macOS accessibility."
                            : "FocusFocus runs with zero permissions. Grant Accessibility to follow windows in real time while dragging.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 14)
                    }
                    
                    Spacer()
                    
                    if !isAccessibilityTrusted {
                        Button("Enable...") {
                            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
            }
            
            // 5. Support
            HStack(alignment: .top, spacing: 14) {
                Text("Support:")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: labelWidth, alignment: .trailing)
                    .padding(.top, 1)
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enjoying FocusFocus?")
                            .font(.body)
                        Text("If you like this, buy me a coffee to support development ☕")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Buy Coffee...") {
                        if let url = URL(string: "https://github.com/sponsors/rfdixon") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 530)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != isAccessibilityTrusted {
                isAccessibilityTrusted = trusted
                (NSApp.delegate as? AppDelegate)?.checkAccessibilityUpgrade()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { note in
            if let panel = note.object as? NSColorPanel, panel.isVisible {
                settings.tintColor = panel.color
            }
        }
    }
    
    private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = settings.tintColor
        panel.isContinuous = true
        panel.showsAlpha = false
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
