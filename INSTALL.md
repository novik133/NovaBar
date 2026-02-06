# NovaBar Installation Guide

## Quick Installation

### 1. Install the Package
```bash
sudo dpkg -i novabar_0.1.3_amd64.deb
```

### 2. Fix Dependencies (if needed)
If you see dependency errors, run:
```bash
sudo apt-get install -f
```

This will automatically install all required dependencies.

### 3. Start NovaBar
```bash
novabar &
```

Or simply log out and log back in - NovaBar will start automatically.

## Detailed Installation Steps

### Prerequisites Check
Before installing, verify you have the required dependencies:

```bash
dpkg -l | grep -E "libgtk-3-0|libglib2.0-0|libwnck-3-0|libnm0|libgtk-layer-shell0|libwayland-client0"
```

### Install Missing Dependencies
If any dependencies are missing:

```bash
sudo apt-get update
sudo apt-get install libgtk-3-0 libglib2.0-0 libwnck-3-0 libnm0 libgtk-layer-shell0 libwayland-client0
```

### Verify Package Integrity
Before installation, verify the package hasn't been corrupted:

```bash
sha256sum -c novabar_0.1.3_amd64.deb.sha256
```

You should see: `novabar_0.1.3_amd64.deb: OK`

### Install NovaBar
```bash
sudo dpkg -i novabar_0.1.3_amd64.deb
```

### Verify Installation
```bash
which novabar
# Should output: /usr/bin/novabar

ls -l /usr/share/applications/novabar.desktop
# Should show the desktop file exists
```

## First Run

### Manual Start
```bash
novabar &
```

### Autostart
NovaBar is configured to start automatically on login. The autostart file is located at:
```
/etc/xdg/autostart/novabar-autostart.desktop
```

To disable autostart, you can:
1. Remove the autostart file: `sudo rm /etc/xdg/autostart/novabar-autostart.desktop`
2. Or create a user override: `mkdir -p ~/.config/autostart && cp /etc/xdg/autostart/novabar-autostart.desktop ~/.config/autostart/ && echo "Hidden=true" >> ~/.config/autostart/novabar-autostart.desktop`

## Configuration

### Settings Location
User settings are stored in:
```
~/.config/novabar/
```

### Access Settings
Right-click on the panel and select "NovaBar Settings..." to configure:
- **Theme**: Choose between Light and Dark themes
- **Logo Icon**: Customize the panel logo
- **Network**: Configure network indicator preferences

### Network Indicator Settings
- **Auto-connect to known networks**: Automatically connect to saved WiFi networks
- **Show network notifications**: Display notifications for network events
- **Show bandwidth monitor**: Enable real-time bandwidth monitoring

## Using NovaBar

### Panel Features
- **Logo Menu** (left): Application launcher and system menu
- **Global Menu** (center): Application menu bar (macOS-style)
- **Indicators** (right): System status indicators

### Network Indicator
Click the network icon to:
- View and connect to WiFi networks
- Manage VPN connections
- Monitor mobile data usage
- Create WiFi hotspots
- View bandwidth statistics
- Configure network settings

### Keyboard Shortcuts
- **Tab**: Navigate between UI elements
- **Enter/Space**: Activate selected item
- **Escape**: Close popover/dialog
- **F5**: Refresh network list
- **Arrow Keys**: Navigate lists

## Troubleshooting

### NovaBar doesn't start
1. Check if it's already running: `ps aux | grep novabar`
2. Kill existing instance: `killall novabar`
3. Start with verbose output: `novabar -v`

### Network indicator not working
1. Verify NetworkManager is running: `systemctl status NetworkManager`
2. Check permissions: NovaBar uses PolicyKit for privileged operations
3. Restart NovaBar: `killall novabar && novabar &`

### Panel not visible
1. Check display server: `echo $XDG_SESSION_TYPE`
2. For Wayland: Ensure gtk-layer-shell is installed
3. For X11: Check window manager compatibility

### Dependencies missing
```bash
sudo apt-get install -f
```

## Building from Source

If you prefer to build NovaBar yourself instead of using the `.deb` package:

### Build Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install valac meson ninja-build pkg-config gettext \
    libgtk-3-dev libglib2.0-dev libgio2.0-dev \
    libgdk-x11-3.0-dev libwnck-3-dev libx11-dev \
    libnm-dev libsoup-3.0-dev appmenu-gtk-module \
    libgtk-layer-shell-dev libwayland-dev
```

**Fedora:**
```bash
sudo dnf install vala meson ninja-build pkgconf gettext \
    gtk3-devel libwnck3-devel libX11-devel \
    NetworkManager-libnm-devel libsoup3-devel \
    gtk-layer-shell-devel wayland-devel
```

**Arch Linux:**
```bash
sudo pacman -S vala meson ninja pkgconf gtk3 libwnck3 \
    networkmanager libsoup3 gtk-layer-shell wayland gettext
```

**openSUSE:**
```bash
sudo zypper install vala meson ninja pkgconf gtk3-devel libwnck-devel \
    libX11-devel NetworkManager-devel libsoup3-devel \
    gtk-layer-shell-devel wayland-devel gettext-tools
```

### Build & Install
```bash
git clone https://github.com/novik133/NovaBar.git
cd NovaBar
meson setup build
ninja -C build
sudo ninja -C build install
```

### Build without Wayland (X11 only)
```bash
meson setup build -Dwayland=false
ninja -C build
```

## Uninstallation

### Remove Package
```bash
sudo dpkg -r novabar
```

### Remove Package and Configuration
```bash
sudo dpkg --purge novabar
rm -rf ~/.config/novabar
```

## Upgrading

To upgrade to a newer version:
```bash
sudo dpkg -i novabar_<new_version>_amd64.deb
```

The upgrade will preserve your settings.

## Support

### Getting Help
- GitHub Issues: https://github.com/novik133/NovaBar/issues
- Email: novik@noviktech.com

### Reporting Bugs
When reporting bugs, please include:
1. NovaBar version: Check package version with `dpkg -l | grep novabar`
2. System information: `uname -a`
3. Desktop environment: `echo $XDG_CURRENT_DESKTOP`
4. Display server: `echo $XDG_SESSION_TYPE`
5. Error messages: Run `novabar -v` for verbose output

## License
NovaBar is licensed under GPL-3.0. See LICENSE file for details.
