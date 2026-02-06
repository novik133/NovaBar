# NovaBar Wayland Support TODO

Add native Wayland support for XFCE/labwc using gtk-layer-shell while maintaining X11 compatibility.

## Phase 1: Dependencies & Backend Detection ✅

- [x] Add `gtk-layer-shell` dependency (optional, for Wayland)
- [x] Add Vala bindings for gtk-layer-shell (`gtk-layer-shell-0`)
- [x] Update `meson.build` with conditional Wayland dependencies
- [x] Create `src/backend/backend.vala` - runtime detection of X11 vs Wayland
- [x] Create `src/backend/x11.vala` - X11-specific panel setup (struts)
- [x] Create `src/backend/wayland.vala` - Wayland panel setup (gtk-layer-shell)
- [x] Add `meson_options.txt` with `wayland` option

## Phase 2: Panel & Global Menu Abstraction ✅

### Panel Window (`src/panel.vala`)
- [x] Refactor to use backend abstraction
- [x] Wayland: gtk-layer-shell for anchors and exclusive zone
- [x] X11: Keep existing `_NET_WM_STRUT_PARTIAL` implementation

### Window Tracking (`src/toplevel/`)
- [x] Create `src/toplevel/tracker.vala` - Abstract tracker interface
- [x] Create `src/toplevel/x11.vala` - X11 tracker using libwnck
- [x] Create `src/toplevel/wayland.vala` - Wayland tracker using D-Bus

### Global Menu (`src/globalmenu/menubar.vala`)
- [x] Refactor to use `Toplevel.Tracker` interface
- [x] X11: Use X11 properties for menu paths
- [x] Wayland: Use D-Bus for menu discovery

## Phase 3: Popup Windows & Testing ✅

### Popup Window Abstraction
- [x] Create `src/backend/popup.vala` - Cross-platform popup positioning
- [x] Update all indicator popups to use `Backend.setup_popup()`
- [x] Update all indicator popups to use `Backend.position_popup()`
- [x] Fix deprecated `screen.get_width()` calls with monitor geometry

### Updated Indicators
- [x] DateTime popup
- [x] Control Center popup
- [x] Sound popup
- [x] Network popup
- [x] Bluetooth popup
- [x] Battery popup
- [x] Notifications popup

### Testing (Manual)
- [ ] Test on X11/XFCE (existing functionality)
- [ ] Test on labwc (Wayland compositor)
- [ ] Test global menu with GTK3 apps on Wayland
- [ ] Test panel positioning on multi-monitor setups

## Phase 4: Documentation (TODO)

- [ ] Update README.md with Wayland requirements
- [ ] Add labwc configuration example
- [ ] Document environment variables for Wayland

## Project Structure

```
src/
├── backend/                  # ✅ Backend abstraction
│   ├── backend.vala          # Runtime X11/Wayland detection
│   ├── x11.vala              # X11 panel setup (struts)
│   ├── wayland.vala          # Wayland panel setup (gtk-layer-shell)
│   └── popup.vala            # Cross-platform popup positioning
├── toplevel/                 # ✅ Window tracking abstraction
│   ├── tracker.vala          # Abstract tracker interface
│   ├── x11.vala              # libwnck-based tracking
│   └── wayland.vala          # D-Bus-based tracking
├── globalmenu/
│   └── menubar.vala          # ✅ Updated to use tracker abstraction
├── indicators/               # ✅ All popups updated
│   ├── datetime/
│   ├── sound/
│   ├── network/
│   ├── bluetooth/
│   ├── battery/
│   ├── notifications/
│   └── controlcenter/
├── panel.vala                # ✅ Updated to use backend abstraction
└── ...
```

## Build Commands

```bash
# Build with Wayland support (default)
meson setup build
ninja -C build

# Build without Wayland support
meson setup build -Dwayland=false
ninja -C build

# Run
./build/novabar
```

## Testing on Wayland

```bash
# Test with labwc
labwc &
GDK_BACKEND=wayland ./build/novabar

# Test with other wlroots compositors
# Ensure gtk-layer-shell is installed
```

## References

- [gtk-layer-shell](https://github.com/wmww/gtk-layer-shell)
- [wlr-foreign-toplevel-management](https://wayland.app/protocols/wlr-foreign-toplevel-management-unstable-v1)
- [labwc](https://github.com/labwc/labwc)
