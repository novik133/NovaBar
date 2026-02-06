# Changelog

All notable changes to NovaBar will be documented in this file.

## [0.1.3] - 2026-02-06

### Added
- **Enhanced Network Indicator** - Complete network management system integrated into NovaBar
  - Comprehensive WiFi management with network scanning, connection profiles, and hidden network support
  - Ethernet management with cable detection, static IP configuration, and diagnostics
  - VPN support with OpenVPN and WireGuard protocol integration, profile management, and import/export
  - Mobile broadband support with cellular modem detection, data usage tracking, and roaming controls
  - WiFi hotspot functionality with connection sharing, device monitoring, and data usage limits
  - Real-time bandwidth monitoring with speed tests and performance metrics
  - Network security analysis with risk assessment and captive portal detection
  - Network profile management with automatic switching and import/export capabilities
  - Advanced configuration options including proxy settings, custom DNS, and DNS-over-HTTPS
  - PolicyKit integration for secure privilege escalation
  - Comprehensive error handling with automatic recovery mechanisms
  - Full keyboard navigation and screen reader support for accessibility

- **Network Management UI Components**
  - Main network indicator with dynamic status icons and notification system
  - Tabbed popover interface with dedicated panels for each network type
  - WiFi panel with signal strength indicators, security badges, and connection dialogs
  - Ethernet panel with status display and static IP configuration
  - VPN panel with profile management and connection controls
  - Mobile panel with data usage monitoring and APN configuration
  - Hotspot panel with device monitoring and configuration options
  - Monitor panel with real-time bandwidth graphs and speed test interface
  - Settings panel for network profiles and advanced configuration

- **NetworkManager Integration**
  - Complete D-Bus API integration for all network operations
  - Asynchronous network discovery and state monitoring
  - Device detection and management for WiFi, Ethernet, mobile, and VPN
  - Connection profile persistence and automatic reconnection
  - Network event handling and status synchronization

- **Custom Icon File Browser** - Browse for custom logo icon images
  - Added Browse button next to the logo icon entry in Settings > Appearance
  - Opens a file chooser dialog filtered for image files (PNG, SVG, XPM, ICO, JPG)
  - Starts in `/usr/share/pixmaps` with live image preview
  - Logo menu updated to load file paths as pixbufs in addition to icon names

- **Icons Directory** - Created `data/icons/` folder for custom program icons

### Fixed
- **Critical Stability Issues** - Resolved multiple null pointer crashes
  - Fixed string.replace() crashes on null strings throughout network indicator code
  - Fixed printf() crashes with null format strings and arguments
  - Fixed string.down() and string.up() crashes on null strings in search filters
  - Fixed string template interpolation crashes with null variables
  - Fixed string concatenation crashes with null values
  - Added comprehensive null checks to all string operations in 50+ locations
  - Protected all dangerous string operations: replace(), down(), up(), contains(), has_prefix(), has_suffix(), substring(), strip(), split()

- **Network Indicator Popup Positioning** - Fixed popup appearing above the panel
  - Converted `NetworkPopover` from `Gtk.Popover` to `Gtk.Window` popup with explicit screen-coordinate positioning
  - Uses `Backend.position_popup()` matching all other indicator popups
  - Popup now correctly appears below the panel on X11

- **Dark Theme Text Unreadable After Theme Switch** - Fixed font color becoming unreadable when switching light → dark
  - Root cause: `add_provider_for_screen()` was called without removing the previous CSS provider
  - Light theme CSS (with `color: #333`) stayed loaded alongside the dark theme
  - Added shared static `_active_theme_provider` and `apply_theme_css()` helper that removes the old provider before adding the new one

- **Settings Window Header Bar Flickering** - Fixed header bar jumping and disappearing during window drag
  - Removed CSS `background: transparent` and `border-radius: 12px` on the window/header that broke GTK's client-side decoration compositing on X11

- **Rounded Corners on LogoMenu and Context Menu** - Fixed menus having square corners
  - `Gtk.Menu` on X11 creates its own rectangular toplevel window that ignores CSS `border-radius`
  - Converted both LogoMenu and panel right-click context menu from `Gtk.Menu` to custom `Gtk.Window` popups with Cairo-drawn rounded backgrounds
  - Matches the pattern used by Sound, Bluetooth, and all other indicator popups

- **GSettings Schema Errors** - Made all GSettings usage optional
  - Added schema existence checks before GSettings instantiation
  - Implemented graceful fallback to default values when schemas unavailable
  - Fixed crashes in ErrorHandler, VPNManager, MobileManager, AdvancedConfigManager, and NetworkProfileManager
  - Application now works without any GSettings schemas installed

- **Package Dependencies** - Fixed installation on Ubuntu 24.04+ with time64 packages
  - Updated Debian package dependencies to accept both standard and t64 library variants
  - Added flexible dependencies: libgtk-3-0 | libgtk-3-0t64, libglib2.0-0 | libglib2.0-0t64, etc.
  - Package now installs successfully on systems with time64 transition packages

### Changed
- **Settings Window Redesigned** - Complete modern UI overhaul
  - Replaced `Gtk.StackSwitcher` tabs with sidebar navigation using `Gtk.ListBox` with icon+label rows
  - Settings grouped in rounded cards with label, sublabel, and widget rows separated by subtle dividers
  - Uppercase section headers above each card group (THEME, BRANDING, CONNECTION, NOTIFICATIONS)
  - Page titles with large bold text and muted subtitle descriptions
  - Polished About page with centered logo, version, author info, links card, and Ko-fi support button
  - Self-contained CSS with 30+ style classes using `@theme_*` color references for light/dark compatibility
  - Window enlarged to 680×520 with proper header bar
  - "Save" button renamed to "Apply" (no longer auto-closes the window)

- **About This Computer Window Redesigned** - Complete modern UI overhaul
  - Replaced `Gtk.StackSwitcher` tabs with sidebar navigation (Overview, Displays, Storage)
  - Overview page: centered hero section with distro logo (96px), OS name, version; system info card with Kernel, Processor, Memory, Graphics
  - Displays page: page title/subtitle header; each monitor in a rounded card with icon, name, and resolution
  - Storage page: storage cards with device name, progress bar, and usage details
  - Fixed hardcoded "Macintosh HD" disk name — now shows actual device path
  - Window enlarged to 700×500 with crossfade transitions
  - Self-contained CSS matching the Settings window design language

- **LogoMenu Converted to Custom Popup** - Replaced `Gtk.Menu` with `Gtk.Window` popup
  - Cairo-drawn rounded corners with semi-transparent dark background and subtle border
  - Menu items as flat buttons with left-aligned labels and separators
  - Input grab, Escape key, click-outside, and focus-out dismiss handlers

- **Panel Context Menu Converted to Custom Popup** - Same conversion as LogoMenu
  - Rounded corners via Cairo draw handler
  - Proper input grab and dismiss behavior

- Network indicator replaced with enhanced version while maintaining NovaBar compatibility
- Settings panel extended with network configuration options
- Improved error messages throughout network operations
- Enhanced accessibility with comprehensive ARIA labels and keyboard shortcuts

### Technical Details
- **Architecture**: Modular design with clear separation between network management logic, UI components, and system integration
- **Components**: 15+ specialized managers for different network types and features
- **Data Models**: Comprehensive models for WiFi networks, VPN profiles, mobile connections, and hotspot configurations
- **Testing**: Property-based testing framework with 17 correctness properties
- **Integration**: Seamless integration with existing NovaBar indicator system and settings

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
