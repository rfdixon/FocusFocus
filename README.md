# FocusFocus

<div align="center">

<img src="assets/banner.png" alt="FocusFocus Icon" width="200" style="border-radius: 22%;" />

### Elegant Multi-Layer Window Dimmer for macOS

[![Platform](https://img.shields.io/badge/platform-macOS%2012.0%2B%20%7C%20Golden%20Gate-blue.svg?style=flat-square)](https://apple.com/macos)
[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial-blue.svg?style=flat-square)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat-square)](https://swift.org)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%99%A5-ea4aaa.svg?style=flat-square&logo=githubsponsors)](https://github.com/sponsors/rfdixon)

</div>

---

**FocusFocus** helps you find the window you're looking for by dimming background and inactive windows on macOS. FocusFocus features multi-layering that progressively darkens further windows—creating a natural, distraction-free visual depth hierarchy. The Fade into Background feature blends deeper layers into the desktop wallpaper instead of using a solid tint, offering a good balance between visual depth and performance. 

---

## Features

- **Virtually Zero Resource Usage**: Operates silently in the background with ~0% CPU at idle and a low memory footprint. Fully event-driven with zero battery drain on MacBooks.
- **Multi-Layer Depth Dimming**: Progressively exaggerates depth by darkening each successive background layer in the window stack.
- **Active Window or Entire App**: Choose between dimming all other windows except the frontmost window, or keeping all windows of the active app bright together.
- **Zero-Permission Standard Mode**: Works out of the box with **zero system permissions** required.
- **Optional Live Drag Tracking**: Grant Accessibility access only if you want real-time overlay tracking while actively dragging windows.
- **Custom Tint Colors**: Use classic dark tint or personalize with warm sepia, dark navy, or any system color hue.
- **Fade into Desktop Mode**: Optionally blends deeper background layers smoothly into your desktop wallpaper.
- **Multi-Display & Space Aware**: Seamlessly updates across multiple monitors and macOS Spaces.
- **Stage Manager & Mission Control Friendly**: Automatically detects macOS Stage Manager and gracefully pauses dimming overlays to avoid visual conflicts with stage sets and transition animations.
- **Modern macOS Support**: Fully compatible with macOS 12.0 (Monterey) through the newest **macOS Golden Gate**.
- **Sleek Menu Bar Utility**: Zero-clutter status item with live toggle, reactive state icon, and instant preferences.
- **100% Offline & Private**: Zero data collection, no telemetry, no network calls, and runs strictly locally on your Mac.

---

## Installation

### Build from Source (Free)

FocusFocus is source-available and free for personal use under the [PolyForm Noncommercial License 1.0.0](LICENSE). You can clone and build it locally in seconds:

#### Prerequisites
- macOS 12.0 (Monterey) or later (including the newest **macOS Golden Gate**)
- Xcode Command Line Tools (`xcode-select --install`)

#### Build Steps
```bash
# 1. Clone the repository
git clone https://github.com/rfdixon/FocusFocus.git
cd FocusFocus

# 2. Build FocusFocus.app
./build.sh

# 3. Launch the app
open FocusFocus.app
```

#### Optional: Move to Applications
```bash
cp -R FocusFocus.app /Applications/
```

---

## Permissions & Privacy

FocusFocus is built with user privacy and security at its foundation:

- **Zero Permissions Needed**: FocusFocus runs in Standard Mode out of the box without requiring Accessibility or screen recording permissions.
- **Optional Accessibility Permission**: Used exclusively for *Live Drag Tracking* (`AXObserver` events) to track window boundaries in real time while actively dragging.
- **Zero Content Access**: FocusFocus **never** records, captures, or inspects window contents, keystrokes, or screen pixels.
- **Zero Network Calls**: FocusFocus contains zero analytics SDKs, zero telemetry, and zero outbound network traffic.
- See our [Privacy Policy](PRIVACY.md) for complete details.

### Troubleshooting Permissions
If you reinstall or rebuild with a new signature, macOS may occasionally retain stale Accessibility permission entries. You may need to toggle it on and off in the Accessibility settings to clear the old permission. 

---

## Contributing

Contributions, bug reports, and feature suggestions are welcome!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Sponsor & Support

If you find FocusFocus helpful and want to support independent macOS development, consider becoming a sponsor:

[![Sponsor via GitHub](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/rfdixon)

---

## License

FocusFocus is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). Free for personal and non-commercial use. Commercial distribution, resale, or sublicensing is strictly prohibited. Copyright © 2026 Robert Dixon.
