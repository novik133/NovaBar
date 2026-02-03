/**
 * Control Center - macOS-style unified controls
 */

namespace Indicators {

    public class ControlCenter : Gtk.Button {
        private ControlCenterPopup? popup;
        
        public ControlCenter() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            var icon = new Gtk.Image.from_icon_name("view-grid-symbolic", Gtk.IconSize.MENU);
            add(icon);
            
            clicked.connect(show_popup);
        }
        
        private void show_popup() {
            if (popup != null && popup.visible) { popup.hide(); return; }
            
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            if (popup == null) popup = new ControlCenterPopup();
            popup.refresh();
            popup.show_at(x, y);
        }
    }
    
    private class ControlCenterPopup : Gtk.Window {
        private Gtk.Box content_box;
        
        public ControlCenterPopup() {
            Object(type: Gtk.WindowType.POPUP);
            Backend.setup_popup(this, 28);
            set_keep_above(true);
            set_app_paintable(true);
            
            var screen = get_screen();
            var visual = screen.get_rgba_visual();
            if (visual != null) set_visual(visual);
            
            draw.connect((cr) => {
                int w = get_allocated_width();
                int h = get_allocated_height();
                double r = 12;
                cr.new_sub_path();
                cr.arc(w - r, r, r, -Math.PI/2, 0);
                cr.arc(w - r, h - r, r, 0, Math.PI/2);
                cr.arc(r, h - r, r, Math.PI/2, Math.PI);
                cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
                cr.close_path();
                cr.set_source_rgba(0.24, 0.24, 0.24, 0.95);
                cr.fill_preserve();
                cr.set_source_rgba(1, 1, 1, 0.15);
                cr.set_line_width(1);
                cr.stroke();
                return false;
            });
            
            key_press_event.connect((e) => {
                if (e.keyval == Gdk.Key.Escape) { ungrab(); hide(); return true; }
                return false;
            });
            
            button_press_event.connect((e) => {
                int w, h;
                get_size(out w, out h);
                if (e.x < 0 || e.y < 0 || e.x > w || e.y > h) { ungrab(); hide(); }
                return false;
            });
            
            focus_out_event.connect(() => { ungrab(); hide(); return false; });
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content_box.set_size_request(320, -1);
            content_box.margin = 16;
            add(content_box);
        }
        
        private void ungrab() {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null) seat.ungrab();
        }
        
        public void show_at(int x, int y) {
            show_all();
            Backend.position_popup(this, x, y, 28);
            
            if (Backend.is_x11()) {
                var seat = Gdk.Display.get_default().get_default_seat();
                if (seat != null && get_window() != null) {
                    seat.grab(get_window(), Gdk.SeatCapabilities.ALL, true, null, null, null);
                }
            }
            present();
        }
        
        public void refresh() {
            content_box.foreach((w) => w.destroy());
            
            // Top row: WiFi, Bluetooth, Do Not Disturb
            var top_grid = new Gtk.Grid();
            top_grid.column_spacing = 8;
            top_grid.row_spacing = 8;
            top_grid.column_homogeneous = true;
            
            top_grid.attach(create_toggle_tile("network-wireless-symbolic", "Wi-Fi", get_wifi_enabled(), toggle_wifi), 0, 0);
            top_grid.attach(create_toggle_tile("bluetooth-active-symbolic", "Bluetooth", get_bt_enabled(), toggle_bt), 1, 0);
            top_grid.attach(create_toggle_tile("notifications-disabled-symbolic", "Do Not Disturb", false, null), 2, 0);
            
            content_box.pack_start(top_grid, false, false, 0);
            
            // Display brightness
            var display_box = create_slider_section("display-brightness-symbolic", "Display", get_brightness(), set_brightness);
            content_box.pack_start(display_box, false, false, 0);
            
            // Sound volume
            var sound_box = create_slider_section("audio-volume-high-symbolic", "Sound", get_volume(), set_volume);
            content_box.pack_start(sound_box, false, false, 0);
            
            // Now Playing (placeholder)
            var media_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            media_box.get_style_context().add_class("control-tile");
            media_box.margin_top = 4;
            
            var media_icon = new Gtk.Image.from_icon_name("audio-x-generic-symbolic", Gtk.IconSize.DND);
            media_box.pack_start(media_icon, false, false, 8);
            
            var media_label = new Gtk.Label("Not Playing");
            media_label.get_style_context().add_class("dim-label");
            media_label.halign = Gtk.Align.START;
            media_box.pack_start(media_label, true, true, 0);
            
            content_box.pack_start(media_box, false, false, 0);
            
            content_box.show_all();
        }
        
        private Gtk.Widget create_toggle_tile(string icon_name, string label, bool active, owned ToggleFunc? callback) {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            box.get_style_context().add_class("control-tile");
            if (active) box.get_style_context().add_class("active");
            
            var btn = new Gtk.Button();
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("circular");
            
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR);
            btn.add(icon);
            
            if (callback != null) {
                btn.clicked.connect(() => {
                    callback();
                    Timeout.add(500, () => { refresh(); return false; });
                });
            }
            
            box.pack_start(btn, false, false, 4);
            
            var lbl = new Gtk.Label(label);
            lbl.get_style_context().add_class("control-label");
            box.pack_start(lbl, false, false, 0);
            
            return box;
        }
        
        private delegate void ToggleFunc();
        private delegate void SliderFunc(int val);
        
        private Gtk.Widget create_slider_section(string icon_name, string label, int value, owned SliderFunc callback) {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            
            var header = new Gtk.Label(label);
            header.get_style_context().add_class("dim-label");
            header.halign = Gtk.Align.START;
            box.pack_start(header, false, false, 0);
            
            var slider_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            slider_box.get_style_context().add_class("control-tile");
            
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
            slider_box.pack_start(icon, false, false, 8);
            
            var scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5);
            scale.set_draw_value(false);
            scale.hexpand = true;
            scale.set_value(value);
            scale.value_changed.connect(() => callback((int)scale.get_value()));
            slider_box.pack_start(scale, true, true, 8);
            
            box.pack_start(slider_box, false, false, 0);
            return box;
        }
        
        // WiFi
        private bool get_wifi_enabled() {
            try {
                string output;
                Process.spawn_command_line_sync("nmcli radio wifi", out output, null, null);
                return output.strip() == "enabled";
            } catch (Error e) {}
            return false;
        }
        
        private void toggle_wifi() {
            bool enabled = get_wifi_enabled();
            try {
                Process.spawn_command_line_async("nmcli radio wifi " + (enabled ? "off" : "on"));
            } catch (Error e) {}
        }
        
        // Bluetooth
        private bool get_bt_enabled() {
            try {
                string output;
                Process.spawn_command_line_sync("bluetoothctl show", out output, null, null);
                return output.contains("Powered: yes");
            } catch (Error e) {}
            return false;
        }
        
        private void toggle_bt() {
            bool enabled = get_bt_enabled();
            try {
                Process.spawn_command_line_async("bluetoothctl power " + (enabled ? "off" : "on"));
            } catch (Error e) {}
        }
        
        // Brightness
        private int get_brightness() {
            try {
                string output;
                Process.spawn_command_line_sync("brightnessctl -m", out output, null, null);
                var parts = output.split(",");
                if (parts.length >= 4) {
                    string pct = parts[3].replace("%", "");
                    return int.parse(pct);
                }
            } catch (Error e) {}
            return 100;
        }
        
        private void set_brightness(int val) {
            try {
                Process.spawn_command_line_async("brightnessctl set %d%%".printf(val));
            } catch (Error e) {}
        }
        
        // Volume
        private int get_volume() {
            try {
                string output;
                Process.spawn_command_line_sync("pactl get-sink-volume @DEFAULT_SINK@", out output, null, null);
                int idx = output.index_of("%");
                if (idx > 0) {
                    int start = idx - 1;
                    while (start > 0 && output[start-1].isdigit()) start--;
                    return int.parse(output.substring(start, idx - start));
                }
            } catch (Error e) {}
            return 50;
        }
        
        private void set_volume(int val) {
            try {
                Process.spawn_command_line_async("pactl set-sink-volume @DEFAULT_SINK@ %d%%".printf(val));
            } catch (Error e) {}
        }
    }
}
