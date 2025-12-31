# Changelog

All notable changes to NovaBar will be documented in this file.

## [0.1.1] - 2025-12-31

### Added
- **Wayland Support** - Native Wayland support using gtk-layer-shell
  - Panel positioning with proper layer-shell anchors and exclusive zone
  - Popup windows work correctly on Wayland compositors
  - Multi-monitor support using GdkMonitor API

- **wlr-foreign-toplevel-management Protocol** - Window tracking on Wayland
  - Tracks focused window on wlroots-based compositors (labwc, sway, wayfire, etc.)
  - Shows focused window title in global menu area
  - New `src/wayland/` directory with protocol implementation

- **Backend Abstraction Layer**
  - `src/backend/backend.vala` - Runtime X11/Wayland detection
  - `src/backend/x11.vala` - X11-specific panel setup (struts)
  - `src/backend/wayland.vala` - Wayland panel setup (gtk-layer-shell)
  - `src/backend/popup.vala` - Cross-platform popup positioning

- **Toplevel Tracking Abstraction**
  - `src/toplevel/tracker.vala` - Abstract tracker interface
  - `src/toplevel/x11.vala` - X11 tracker using libwnck
  - `src/toplevel/wayland.vala` - Wayland tracker using wlr-foreign-toplevel

### Changed
- All indicator popups updated to use `Backend.setup_popup()` and `Backend.position_popup()`
- Removed deprecated `Gdk.Screen.get_width()` calls, now uses monitor geometry
- Global menu now works on both X11 and Wayland (window title tracking)
- Build system updated with optional Wayland dependencies

### Fixed
- Popup positioning on multi-monitor setups
- Keyboard grab only on X11 (not needed on Wayland)

## [0.1.0] - 2025-12-30

### Added
- Initial release
- macOS-style panel for Linux (X11/XFCE)
- Global menu integration
- System indicators: Network, Bluetooth, Sound, Battery, DateTime, Notifications
- Control Center with quick settings
- Theme support (dark and light themes)
- Settings panel for customization
