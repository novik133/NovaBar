# Changelog

All notable changes to NovaBar will be documented in this file.

## [0.1.2] - 2026-02-03

### Fixed
- **Build System** - Fixed hardcoded 'build' directory reference in meson.build
  - Removed hardcoded `'build'` from `include_directories` that caused "Include dir build does not exist" error
  - Build now works with different build directory names and configurations
  - Fixes compilation issues on Solus and other distributions

- **Fedora 43 Hanging Issue** - Resolved application hanging during startup
  - Made NetworkManager initialization asynchronous to prevent blocking
  - Added comprehensive debug logging throughout application startup
  - Enhanced error handling for NetworkManager client creation
  - Added fallback icons when NetworkManager is unavailable
  - Improved robustness of indicator initialization

### Added
- **Enhanced Debug Output** - Comprehensive logging for troubleshooting
  - Added debug logging to panel construction, indicator creation, and backend setup
  - Verbose mode now shows detailed progress through startup sequence
  - Added debug script (`debug_novabar.sh`) for system diagnostics
  - Better error reporting for NetworkManager and system dependencies

- **Support Information** - Added Ko-fi support link to About tab
  - Added support section encouraging user contributions
  - Ko-fi button with coffee emoji for easy donations
  - Updated copyright to 2025-2026

### Changed
- NetworkManager initialization moved to idle callback to prevent startup hangs
- Improved error handling throughout indicator initialization
- Enhanced debug output for better troubleshooting capabilities

## [0.1.1] - 2025-12-31

### Added
- **Auto-detect Distribution Logo** - Automatically detects distro from `/etc/os-release`
  - Tries icon names: `distributor-logo-{distro}`, `{distro}-logo`, `{distro}`
  - Falls back to `distributor-logo` if no match found
  - User-configured icon in Settings still takes priority

- **Verbose Mode** - Run with `-v` or `--verbose` for detailed startup logs
  - Shows environment detection (Display, Wayland, GDK_BACKEND)
  - Logs backend initialization and component setup
  - Useful for debugging startup issues

### Previously Added
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
