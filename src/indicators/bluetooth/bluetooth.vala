/**
 * Bluetooth Indicator - macOS-style popup
 */

namespace Indicators {

    public class Bluetooth : Gtk.Button {
        private Gtk.Image icon;
        private BluetoothPopup? popup;
        
        public Bluetooth() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            icon = new Gtk.Image.from_icon_name("bluetooth-active-symbolic", Gtk.IconSize.MENU);
            add(icon);
            
            update_icon();
            Timeout.add_seconds(2, () => { update_icon(); return true; });
            
            clicked.connect(show_popup);
        }
        
        public void update_icon() {
            try {
                string output;
                Process.spawn_command_line_sync("bluetoothctl show", out output, null, null);
                if (output.contains("Powered: yes")) {
                    icon.set_from_icon_name("bluetooth-active-symbolic", Gtk.IconSize.MENU);
                    icon.set_from_icon_name("bluetooth-disabled-symbolic", Gtk.IconSize.MENU);
                }
            } catch (Error e) {}
        }
        
        private void show_popup() {
            if (popup != null && popup.visible) {
                popup.hide();
                return;
            }
            
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            if (popup == null) popup = new BluetoothPopup(this);
            popup.refresh();
            popup.show_at(x, y);
        }
    }
    
    private class BluetoothPopup : Gtk.Window {
        private Gtk.Box content_box;
        private weak Bluetooth indicator;
        
        public BluetoothPopup(Bluetooth ind) {
            Object(type: Gtk.WindowType.POPUP);
            Backend.setup_popup(this, 28);
            this.indicator = ind;
            
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
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            content_box.set_size_request(280, -1);
            content_box.margin = 12;
            add(content_box);
        }
        
        private void ungrab() {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null) seat.ungrab();
        }
        
        public void show_at(int x, int y) {
            show_all();
            int w, h;
            get_size(out w, out h);
            Backend.position_popup(this, x, y, 28);
            var seat = Gdk.Display.get_default().get_default_seat();
            if (Backend.is_x11() && seat != null && get_window() != null) {
                seat.grab(get_window(), Gdk.SeatCapabilities.ALL, true, null, null, null);
            }
            present();
        }
        
        public void refresh() {
            content_box.foreach((w) => w.destroy());
            
            // Header with toggle
            var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            header.margin_bottom = 8;
            
            var label = new Gtk.Label("Bluetooth");
            label.get_style_context().add_class("section-title");
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            
            var toggle = new Gtk.Switch();
            toggle.active = is_bluetooth_enabled();
            toggle.notify["active"].connect(() => {
                set_bluetooth_enabled(toggle.active);
                indicator.update_icon();
                Timeout.add(500, () => { refresh(); return false; });
            });
            
            header.pack_start(label, true, true, 0);
            header.pack_end(toggle, false, false, 0);
            content_box.pack_start(header, false, false, 0);
            
            if (!toggle.active) {
                content_box.show_all();
                return;
            }
            
            // Connected devices
            var devices = get_connected_devices();
            if (devices.length > 0) {
                foreach (var dev in devices) {
                    var row = create_device_row(dev.name, dev.icon, true);
                    content_box.pack_start(row, false, false, 0);
                }
                content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 8);
            }
            
            // Available devices
            var other_label = new Gtk.Label("Nearby Devices");
            other_label.get_style_context().add_class("dim-label");
            other_label.halign = Gtk.Align.START;
            other_label.margin_top = 4;
            other_label.margin_bottom = 4;
            content_box.pack_start(other_label, false, false, 0);
            
            var available = get_available_devices();
            if (available.length > 0) {
                foreach (var dev in available) {
                    var row = create_device_row(dev.name, dev.icon, false);
                    content_box.pack_start(row, false, false, 0);
                }
                var none = new Gtk.Label("No devices found");
                none.get_style_context().add_class("dim-label");
                none.margin = 8;
                content_box.pack_start(none, false, false, 0);
            }
            
            // Settings button
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 8);
            var settings = new Gtk.Button.with_label("Bluetooth Settings...");
            settings.get_style_context().add_class("flat");
            settings.clicked.connect(() => {
                ungrab(); hide();
                try { Process.spawn_command_line_async("blueman-manager"); } catch (Error e) {}
            });
            content_box.pack_start(settings, false, false, 0);
            
            content_box.show_all();
        }
        
        private Gtk.Button create_device_row(string name, string icon_name, bool connected) {
            var btn = new Gtk.Button();
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("network-row");
            
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 6;
            
            var icon = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.MENU);
            box.pack_start(icon, false, false, 0);
            
            var lbl = new Gtk.Label(name);
            lbl.halign = Gtk.Align.START;
            lbl.hexpand = true;
            lbl.ellipsize = Pango.EllipsizeMode.END;
            box.pack_start(lbl, true, true, 0);
            
            if (connected) {
                var check = new Gtk.Image.from_icon_name("object-select-symbolic", Gtk.IconSize.MENU);
                box.pack_end(check, false, false, 0);
            }
            
            btn.add(box);
            return btn;
        }
        
        private struct BtDevice { string name; string icon; }
        
        private bool is_bluetooth_enabled() {
            try {
                string output;
                Process.spawn_command_line_sync("bluetoothctl show", out output, null, null);
                return output.contains("Powered: yes");
            } catch (Error e) { return false; }
        }
        
        private void set_bluetooth_enabled(bool enabled) {
            try {
                Process.spawn_command_line_sync("bluetoothctl power " + (enabled ? "on" : "off"), null, null, null);
            } catch (Error e) {}
        }
        
        private BtDevice[] get_connected_devices() {
            BtDevice[] devices = {};
            try {
                string output;
                Process.spawn_command_line_sync("bluetoothctl devices Connected", out output, null, null);
                foreach (var line in output.split("\n")) {
                    if (line.has_prefix("Device ")) {
                        var parts = line.split(" ", 3);
                        if (parts.length >= 3) {
                            devices += BtDevice() { name = parts[2], icon = "bluetooth-symbolic" };
                        }
                    }
                }
            } catch (Error e) {}
            return devices;
        }
        
        private BtDevice[] get_available_devices() {
            BtDevice[] devices = {};
            try {
                string output;
                Process.spawn_command_line_sync("bluetoothctl devices", out output, null, null);
                var connected = get_connected_devices();
                foreach (var line in output.split("\n")) {
                    if (line.has_prefix("Device ")) {
                        var parts = line.split(" ", 3);
                        if (parts.length >= 3) {
                            bool is_connected = false;
                            foreach (var c in connected) {
                                if (c.name == parts[2]) { is_connected = true; break; }
                            }
                            if (!is_connected) {
                                devices += BtDevice() { name = parts[2], icon = "bluetooth-symbolic" };
                            }
                        }
                    }
                }
            } catch (Error e) {}
            return devices;
        }
    }
}
