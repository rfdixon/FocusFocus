import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings = Settings.shared
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    
    // Binding to convert between NSColor and SwiftUI Color
    var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: settings.tintColor) },
            set: { settings.tintColor = NSColor($0) }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FocusFocus Preferences")
                .font(.headline)
            
            HStack {
                Toggle("Enable Dimming", isOn: $settings.isEnabled)
                Spacer()
                Toggle("Fade into Desktop", isOn: $settings.fadeIntoDesktop)
            }
            
            ColorPicker("Tint Color", selection: colorBinding)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Focus Scope")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("", selection: $settings.focusMode) {
                    ForEach(FocusMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(settings.focusMode == .singleWindow 
                    ? "Only the frontmost window stays bright; all other windows are dimmed."
                    : "All windows belonging to the active application stay bright together.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("Base Darkness: \(Int(settings.baseDarkness * 100))%")
                Slider(value: $settings.baseDarkness, in: 0.0...0.8, step: 0.01)
                Text("Controls the overall darkness of the first layer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("Depth Multiplier: \(Int(settings.depthMultiplier * 100))%")
                Slider(value: $settings.depthMultiplier, in: 0.0...0.3, step: 0.01)
                Text("Makes each progressively further layer even darker to exaggerate depth.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                if isAccessibilityTrusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Live Drag Tracking Active")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Real-time window tracking while dragging is active via macOS accessibility events.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.blue)
                        Text("Standard Mode (Zero Permissions)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("FocusFocus works out of the box with zero system permissions. Live Drag Tracking is an optional enhancement that follows windows in real time while actively dragging.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button("Enable Live Drag Tracking (Optional)") {
                        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                let trusted = AXIsProcessTrusted()
                if trusted != isAccessibilityTrusted {
                    isAccessibilityTrusted = trusted
                    (NSApp.delegate as? AppDelegate)?.checkAccessibilityUpgrade()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 540)
    }
}
