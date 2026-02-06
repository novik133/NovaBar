## NovaBar v0.1.0 - Initial Release

### Added
- Initial release of NovaBar
- macOS-style panel for Linux (X11/XFCE)
- Global menu integration with GTK applications
- Logo menu with system actions (About, Settings, Sleep, Restart, Shutdown)
- System indicators:
  - Network status with NetworkManager integration
  - Bluetooth connectivity indicator
  - Sound/volume control
  - Battery status and charging indicator
  - Date and time display
  - Notification center
  - Control center for quick settings
- Settings panel with theme customization
- Dark and light theme support
- CSS-based styling system
- X11 strut reservation for proper panel positioning
- About dialog with application information
- Modular architecture for easy extension
- Meson build system integration
- Auto-start desktop entry support

### Technical Features
- Built with Vala and GTK3
- libwnck integration for window management
- D-Bus communication for global menus
- NetworkManager (libnm) integration
- X11 window system compatibility
- appmenu-gtk-module support

### Package Downloads
- **Arch Linux**: `novabar-0.1.0-1-x86_64.pkg.tar.zst` + signature
- **Debian/Ubuntu**: `novabar_0.1.0-1_amd64.deb` + signature  
- **Fedora/RHEL**: `novabar-0.1.0-1.x86_64.rpm` + signature
- **Debug symbols**: `novabar-debug-0.1.0-1-x86_64.pkg.tar.zst` + signature

All packages are GPG signed for security verification.
