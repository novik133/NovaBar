/**
 * Popup Helper - Cross-platform popup window positioning
 */

namespace Backend {
    
    public void setup_popup(Gtk.Window popup, int panel_height) {
        popup.set_decorated(false);
        popup.set_skip_taskbar_hint(true);
        popup.set_skip_pager_hint(true);
        popup.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU);
        
#if HAVE_WAYLAND
        if (is_wayland() && GtkLayerShell.is_supported()) {
            GtkLayerShell.init_for_window(popup);
            GtkLayerShell.set_layer(popup, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_namespace(popup, "novabar-popup");
            
            // Anchor to top-right
            GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.RIGHT, true);
            GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.LEFT, false);
            GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.BOTTOM, false);
            
            // Margin from top - just below panel (panel reserves exclusive zone)
            GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.TOP, 0);
            GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.RIGHT, 8);
            
            // Set keyboard interactivity
            GtkLayerShell.set_keyboard_mode(popup, GtkLayerShell.KeyboardMode.ON_DEMAND);
        }
#endif
    }
    
    public void position_popup(Gtk.Window popup, int x, int y, int panel_height) {
        if (is_wayland()) {
#if HAVE_WAYLAND
            if (GtkLayerShell.is_supported()) {
                // On Wayland, position using margins from edges
                var display = Gdk.Display.get_default();
                var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
                var geom = monitor.get_geometry();
                
                int w, h;
                popup.get_size(out w, out h);
                
                int margin_right = geom.width - x - w / 2;
                if (margin_right < 8) margin_right = 8;
                
                GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.RIGHT, margin_right);
                // TOP margin = 4 (small gap below panel's exclusive zone)
                GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.TOP, 0);
            }
#endif
        } else {
            // X11: use move() - y already includes panel offset from caller
            int w, h;
            popup.get_size(out w, out h);
            
            var display = Gdk.Display.get_default();
            var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
            var geom = monitor.get_geometry();
            
            int new_x = x - w / 2;
            if (new_x + w > geom.x + geom.width) new_x = geom.x + geom.width - w - 8;
            if (new_x < geom.x + 8) new_x = geom.x + 8;
            
            popup.move(new_x, y);
        }
    }
}
