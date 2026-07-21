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
            
            VStack(alignment: .leading, spacing: 5) {
                if isAccessibilityTrusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility Access Granted")
                            .font(.subheadline)
                    }
                    Text("The app is using the efficient, low-CPU accessibility API.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Accessibility Access Required")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Text("FocusFocus needs accessibility permissions to efficiently track window movements. Currently falling back to high-CPU polling.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button("Open System Settings") {
                        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
                let trusted = AXIsProcessTrusted()
                if trusted != isAccessibilityTrusted {
                    isAccessibilityTrusted = trusted
                }
            }
        }
        .padding()
        .frame(width: 400, height: 480)
    }
}
