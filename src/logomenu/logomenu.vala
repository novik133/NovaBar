/**
 * LogoMenu - Nova logo menu with system actions
 */

namespace LogoMenu {

    private class NovaMenuPopup : Gtk.Window {
        private Gtk.Box content_box;
        
        public NovaMenuPopup() {
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
                double r = 10;
                cr.new_sub_path();
                cr.arc(w - r, r, r, -Math.PI/2, 0);
                cr.arc(w - r, h - r, r, 0, Math.PI/2);
                cr.arc(r, h - r, r, Math.PI/2, Math.PI);
                cr.arc(r, r, r, Math.PI, 3*Math.PI/2);
                cr.close_path();
                cr.set_source_rgba(0.22, 0.22, 0.22, 0.96);
                cr.fill_preserve();
                cr.set_source_rgba(1, 1, 1, 0.12);
                cr.set_line_width(1);
                cr.stroke();
                return false;
            });
            
            key_press_event.connect((e) => {
                if (e.keyval == Gdk.Key.Escape) { dismiss(); return true; }
                return false;
            });
            
            button_press_event.connect((e) => {
                int w, h;
                get_size(out w, out h);
                if (e.x < 0 || e.y < 0 || e.x > w || e.y > h) { dismiss(); }
                return false;
            });
            
            focus_out_event.connect(() => { dismiss(); return false; });
            
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box.margin = 6;
            content_box.set_size_request(220, -1);
            add(content_box);
        }
        
        public delegate void ItemCallback();
        
        public void add_item(string label, owned ItemCallback cb) {
            var btn = new Gtk.Button.with_label(label);
            btn.get_style_context().add_class("flat");
            btn.get_style_context().add_class("nova-menu-item");
            btn.halign = Gtk.Align.FILL;
            ((Gtk.Label)btn.get_child()).halign = Gtk.Align.START;
            ((Gtk.Label)btn.get_child()).margin_start = 6;
            btn.clicked.connect(() => {
                dismiss();
                cb();
            });
            content_box.pack_start(btn, false, false, 0);
        }
        
        public void add_separator() {
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.margin_top = 4;
            sep.margin_bottom = 4;
            sep.margin_start = 8;
            sep.margin_end = 8;
            sep.opacity = 0.2;
            content_box.pack_start(sep, false, false, 0);
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
        
        public void dismiss() {
            var seat = Gdk.Display.get_default().get_default_seat();
            if (seat != null) seat.ungrab();
            hide();
        }
    }

    public class NovaMenu : Gtk.Button {
        private NovaMenuPopup? popup;
        private Gtk.Image icon;
        
        public NovaMenu() {
            var logo_value = Settings.get_logo_icon();
            if (logo_value.has_prefix("/") && FileUtils.test(logo_value, FileTest.EXISTS)) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(logo_value, 16, 16, true);
                    icon = new Gtk.Image.from_pixbuf(pixbuf);
                } catch (Error e) {
                    icon = new Gtk.Image.from_icon_name("distributor-logo", Gtk.IconSize.MENU);
                }
            } else {
                icon = new Gtk.Image.from_icon_name(logo_value, Gtk.IconSize.MENU);
            }
            set_image(icon);
            set_always_show_image(true);
            get_style_context().add_class("flat");
            get_style_context().add_class("nova-logo");
            
            clicked.connect(on_clicked);
        }
        
        private void on_clicked() {
            if (popup != null && popup.visible) {
                popup.dismiss();
                return;
            }
            
            if (popup == null) {
                popup = build_popup();
            }
            
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            x += alloc.x;
            y += alloc.y + alloc.height + 4;
            
            popup.show_at(x, y);
        }
        
        private NovaMenuPopup build_popup() {
            var p = new NovaMenuPopup();
            
            p.add_item("About This Computer", () => {
                var window = new About.AboutWindow();
                window.show_all();
            });
            p.add_separator();
            
            p.add_item("System Settings...", () => launch("xfce4-settings-manager"));
            p.add_item("App Store...", () => launch("pamac-manager"));
            p.add_separator();
            
            p.add_item("Force Quit...", () => launch("xkill"));
            p.add_separator();
            
            p.add_item("Sleep", () => run_command("systemctl suspend"));
            p.add_item("Restart...", () => run_command("systemctl reboot"));
            p.add_item("Shut Down...", () => run_command("systemctl poweroff"));
            p.add_separator();
            
            p.add_item("Lock Screen", () => run_command("xflock4"));
            p.add_item("Log Out...", () => run_command("xfce4-session-logout"));
            
            return p;
        }
        
        private void launch(string app) {
            try {
                Process.spawn_command_line_async(app);
            } catch (Error e) {}
        }
        
        private void run_command(string cmd) {
            try {
                Process.spawn_command_line_async(cmd);
            } catch (Error e) {}
        }
        
        public void set_icon(string icon_name) {
            if (icon_name.has_prefix("/") && FileUtils.test(icon_name, FileTest.EXISTS)) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(icon_name, 16, 16, true);
                    icon.set_from_pixbuf(pixbuf);
                    return;
                } catch (Error e) {}
            }
            icon.set_from_icon_name(icon_name, Gtk.IconSize.MENU);
        }
    }
}
