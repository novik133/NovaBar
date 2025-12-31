/**
 * Sound Indicator - macOS-style popup
 */

namespace Indicators {

    public class Sound : Gtk.Button {
        private Gtk.Image icon;
        private SoundPopup? popup;
        
        public Sound() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            icon = new Gtk.Image.from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.MENU);
            add(icon);
            
            update_icon();
            Timeout.add_seconds(2, () => { update_icon(); return true; });
            
            clicked.connect(show_popup);
        }
        
        public void update_icon() {
            int vol = get_volume();
            bool muted = is_muted();
            if (muted || vol == 0) icon.set_from_icon_name("audio-volume-muted-symbolic", Gtk.IconSize.MENU);
            else if (vol < 33) icon.set_from_icon_name("audio-volume-low-symbolic", Gtk.IconSize.MENU);
            else if (vol < 66) icon.set_from_icon_name("audio-volume-medium-symbolic", Gtk.IconSize.MENU);
            else icon.set_from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.MENU);
        }
        
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
        
        private bool is_muted() {
            try {
                string output;
                Process.spawn_command_line_sync("pactl get-sink-mute @DEFAULT_SINK@", out output, null, null);
                return output.contains("yes");
            } catch (Error e) {}
            return false;
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
            
            if (popup == null) popup = new SoundPopup(this);
            popup.refresh();
            popup.show_at(x, y);
        }
    }
    
    private class SoundPopup : Gtk.Window {
        private Gtk.Box content_box;
        private weak Sound indicator;
        private Gtk.Scale volume_scale;
        private bool updating = false;
        
        public SoundPopup(Sound ind) {
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
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
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
            
            // Output section
            var out_label = new Gtk.Label("Output");
            out_label.get_style_context().add_class("section-title");
            out_label.halign = Gtk.Align.START;
            content_box.pack_start(out_label, false, false, 0);
            
            // Volume slider with icon
            var vol_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            
            var vol_icon = new Gtk.Image.from_icon_name("audio-volume-high-symbolic", Gtk.IconSize.MENU);
            vol_box.pack_start(vol_icon, false, false, 0);
            
            volume_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5);
            volume_scale.set_draw_value(false);
            volume_scale.hexpand = true;
            volume_scale.set_value(get_volume());
            volume_scale.value_changed.connect(() => {
                if (updating) return;
                int vol = (int)volume_scale.get_value();
                set_volume(vol);
                indicator.update_icon();
            });
            vol_box.pack_start(volume_scale, true, true, 0);
            
            content_box.pack_start(vol_box, false, false, 0);
            
            // Output devices
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
            
            var devices = get_output_devices();
            string default_sink = get_default_sink();
            
            foreach (var dev in devices) {
                var row = create_device_row(dev.name, dev.desc, dev.name == default_sink);
                content_box.pack_start(row, false, false, 0);
            }
            
            // Settings
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 4);
            var settings = new Gtk.Button.with_label("Sound Settings...");
            settings.get_style_context().add_class("flat");
            settings.clicked.connect(() => {
                ungrab(); hide();
                try { Process.spawn_command_line_async("pavucontrol"); } catch (Error e) {}
            });
            content_box.pack_start(settings, false, false, 0);
            
            content_box.show_all();
        }
        
        private Gtk.Button create_device_row(string name, string desc, bool active) {
            var btn = new Gtk.Button();
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("network-row");
            
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            box.margin = 6;
            
            var icon = new Gtk.Image.from_icon_name("audio-speakers-symbolic", Gtk.IconSize.MENU);
            box.pack_start(icon, false, false, 0);
            
            var lbl = new Gtk.Label(desc);
            lbl.halign = Gtk.Align.START;
            lbl.hexpand = true;
            lbl.ellipsize = Pango.EllipsizeMode.END;
            lbl.max_width_chars = 25;
            box.pack_start(lbl, true, true, 0);
            
            if (active) {
                var check = new Gtk.Image.from_icon_name("object-select-symbolic", Gtk.IconSize.MENU);
                box.pack_end(check, false, false, 0);
            }
            
            btn.add(box);
            
            var n = name;
            btn.clicked.connect(() => {
                set_default_sink(n);
                refresh();
            });
            
            return btn;
        }
        
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
        
        private void set_volume(int vol) {
            try {
                Process.spawn_command_line_async("pactl set-sink-volume @DEFAULT_SINK@ %d%%".printf(vol));
            } catch (Error e) {}
        }
        
        private struct AudioDevice { string name; string desc; }
        
        private AudioDevice[] get_output_devices() {
            AudioDevice[] devices = {};
            try {
                string output;
                Process.spawn_command_line_sync("pactl list sinks short", out output, null, null);
                foreach (var line in output.split("\n")) {
                    var parts = line.split("\t");
                    if (parts.length >= 2) {
                        string name = parts[1];
                        string desc = name;
                        // Try to get description
                        string info;
                        Process.spawn_command_line_sync("pactl list sinks", out info, null, null);
                        int name_idx = info.index_of("Name: " + name);
                        if (name_idx >= 0) {
                            int desc_idx = info.index_of("Description: ", name_idx);
                            if (desc_idx >= 0) {
                                int end = info.index_of("\n", desc_idx);
                                if (end > desc_idx) {
                                    desc = info.substring(desc_idx + 13, end - desc_idx - 13);
                                }
                            }
                        }
                        devices += AudioDevice() { name = name, desc = desc };
                    }
                }
            } catch (Error e) {}
            return devices;
        }
        
        private string get_default_sink() {
            try {
                string output;
                Process.spawn_command_line_sync("pactl get-default-sink", out output, null, null);
                return output.strip();
            } catch (Error e) {}
            return "";
        }
        
        private void set_default_sink(string name) {
            try {
                Process.spawn_command_line_async("pactl set-default-sink " + name);
            } catch (Error e) {}
        }
    }
}
