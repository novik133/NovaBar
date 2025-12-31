/**
 * Battery Indicator - macOS-style popup
 */

namespace Indicators {

    public class Battery : Gtk.Button {
        private Gtk.Image icon;
        private Gtk.Label percent_label;
        private BatteryPopup? popup;
        
        public Battery() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            icon = new Gtk.Image.from_icon_name("battery-full-symbolic", Gtk.IconSize.MENU);
            percent_label = new Gtk.Label("");
            
            box.pack_start(icon, false, false, 0);
            box.pack_start(percent_label, false, false, 0);
            add(box);
            
            if (!has_battery()) {
                no_show_all = true;
                hide();
                return;
            }
            
            update_status();
            Timeout.add_seconds(30, () => { update_status(); return true; });
            clicked.connect(show_popup);
        }
        
        public static bool has_battery() {
            return FileUtils.test("/sys/class/power_supply/BAT0", FileTest.EXISTS) ||
                   FileUtils.test("/sys/class/power_supply/BAT1", FileTest.EXISTS);
        }
        
        private void update_status() {
            int percent = get_percent();
            bool charging = is_charging();
            bool on_ac = is_on_ac();
            percent_label.set_text("%d%%".printf(percent));
            
            string icon_name;
            if (on_ac || charging) {
                icon_name = "battery-full-charging-symbolic";
            } else if (percent > 80) {
                icon_name = "battery-full-symbolic";
            } else if (percent > 50) {
                icon_name = "battery-good-symbolic";
            } else if (percent > 20) {
                icon_name = "battery-low-symbolic";
            } else {
                icon_name = "battery-caution-symbolic";
            }
            icon.set_from_icon_name(icon_name, Gtk.IconSize.MENU);
        }
        
        private int get_percent() {
            try {
                string now_str = "";
                string full_str = "";
                FileUtils.get_contents("/sys/class/power_supply/BAT0/charge_now", out now_str);
                FileUtils.get_contents("/sys/class/power_supply/BAT0/charge_full", out full_str);
                double now = double.parse(now_str.strip());
                double full = double.parse(full_str.strip());
                if (full > 0) return (int)((now / full) * 100);
            } catch (Error e) {}
            return 100;
        }
        
        private bool is_charging() {
            try {
                string output = "";
                FileUtils.get_contents("/sys/class/power_supply/BAT0/status", out output);
                return output.strip() == "Charging";
            } catch (Error e) {}
            return false;
        }
        
        private bool is_on_ac() {
            try {
                string output = "";
                if (FileUtils.test("/sys/class/power_supply/AC0/online", FileTest.EXISTS)) {
                    FileUtils.get_contents("/sys/class/power_supply/AC0/online", out output);
                } else if (FileUtils.test("/sys/class/power_supply/ADP0/online", FileTest.EXISTS)) {
                    FileUtils.get_contents("/sys/class/power_supply/ADP0/online", out output);
                } else if (FileUtils.test("/sys/class/power_supply/ADP1/online", FileTest.EXISTS)) {
                    FileUtils.get_contents("/sys/class/power_supply/ADP1/online", out output);
                }
                return output.strip() == "1";
            } catch (Error e) {}
            return false;
        }
        
        private void show_popup() {
            if (popup != null && popup.visible) { popup.hide(); return; }
            
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            if (popup == null) popup = new BatteryPopup();
            popup.refresh(get_percent(), is_charging() || is_on_ac());
            popup.show_at(x, y);
        }
    }
    
    private class BatteryPopup : Gtk.Window {
        private Gtk.Box content_box;
        
        public BatteryPopup() {
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
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            content_box.set_size_request(200, -1);
            content_box.margin = 12;
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
        
        public void refresh(int percent, bool charging) {
            content_box.foreach((w) => w.destroy());
            
            var label = new Gtk.Label("Battery");
            label.get_style_context().add_class("section-title");
            label.halign = Gtk.Align.START;
            content_box.pack_start(label, false, false, 0);
            
            var status = new Gtk.Label(charging ? "Charging - %d%%".printf(percent) : "%d%%".printf(percent));
            status.halign = Gtk.Align.START;
            content_box.pack_start(status, false, false, 0);
            
            var progress = new Gtk.ProgressBar();
            progress.set_fraction(percent / 100.0);
            content_box.pack_start(progress, false, false, 4);
            
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
            
            var settings = new Gtk.Button.with_label("Power Settings...");
            settings.get_style_context().add_class("flat");
            settings.clicked.connect(() => {
                ungrab(); hide();
                try { Process.spawn_command_line_async("xfce4-power-manager-settings"); } catch (Error e) {}
            });
            content_box.pack_start(settings, false, false, 0);
            
            content_box.show_all();
        }
    }
}
