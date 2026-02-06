# GlobalMenu Module

GTK Global Menu widget that displays application menus in the panel.

## Features

- Tracks active window via libwnck
- Reads menus from GTK apps via org.gtk.Menus D-Bus interface
- Supports appmenu-gtk-module
- Activates actions via org.gtk.Actions

## Usage

```vala
var menubar = new GlobalMenu.MenuBar();
menubar.set_panel_window(panel);
container.pack_start(menubar, false, false, 0);
```

## Files

- `menubar.vala` - Main widget implementation

## Dependencies

- gtk+-3.0
- libwnck-3.0
- x11
