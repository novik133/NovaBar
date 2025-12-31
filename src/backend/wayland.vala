/**
 * Wayland Panel Setup - gtk-layer-shell integration
 */

namespace Backend.Wayland {
    
    public void setup_panel_window(Gtk.Window window, int panel_height) {
#if HAVE_WAYLAND
        if (!GtkLayerShell.is_supported()) {
            warning("gtk-layer-shell not supported on this compositor");
            return;
        }
        
        GtkLayerShell.init_for_window(window);
        GtkLayerShell.set_layer(window, GtkLayerShell.Layer.TOP);
        GtkLayerShell.set_namespace(window, "novabar");
        
        // Anchor to top, left, right
        GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP, true);
        GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.RIGHT, true);
        GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.BOTTOM, false);
        
        // Reserve space for the panel
        GtkLayerShell.set_exclusive_zone(window, panel_height);
        
        // Set to primary monitor (null = all monitors, or use specific monitor)
        var display = Gdk.Display.get_default();
        var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
        if (monitor != null) {
            GtkLayerShell.set_monitor(window, monitor);
        }
        
        // No margins needed when anchored
        GtkLayerShell.set_margin(window, GtkLayerShell.Edge.TOP, 0);
        GtkLayerShell.set_margin(window, GtkLayerShell.Edge.LEFT, 0);
        GtkLayerShell.set_margin(window, GtkLayerShell.Edge.RIGHT, 0);
#else
        warning("Wayland support not compiled in");
#endif
    }
}
