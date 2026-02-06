/**
 * DateTime Indicator - Modern calendar popup
 */

namespace Indicators {

    public class DateTime : Gtk.Button {
        private Gtk.Label time_label;
        private CalendarPopup? popup;
        
        public DateTime() {
            get_style_context().add_class("flat");
            get_style_context().add_class("indicator");
            
            time_label = new Gtk.Label("");
            add(time_label);
            
            update_time();
            Timeout.add_seconds(1, update_time);
            
            clicked.connect(show_popup);
        }
        
        private bool update_time() {
            var now = new GLib.DateTime.now_local();
            // 🎆 New Year's Eve Easter Egg
            if (now.get_month() == 12 && now.get_day_of_month() == 31) {
                time_label.set_text("🎆 " + now.format("%H:%M"));
                set_tooltip_text("Happy New Year! 🎉");
            } else {
                time_label.set_text(now.format("%a %b %e  %H:%M"));
                set_tooltip_text(null);
            }
            return true;
        }
        
        private void show_popup() {
            if (popup != null && popup.visible) { popup.hide(); return; }
            
            int x, y;
            Gtk.Allocation alloc;
            get_allocation(out alloc);
            get_window().get_origin(out x, out y);
            x += alloc.x + alloc.width / 2;
            y += alloc.y + alloc.height + 4;
            
            if (popup == null) popup = new CalendarPopup();
            popup.refresh();
            popup.show_at(x, y);
        }
    }
    
    private class CalendarPopup : Gtk.Window {
        private Gtk.Box content_box;
        private int display_month;
        private int display_year;
        
        public CalendarPopup() {
            Object(type: Gtk.WindowType.POPUP);
            
            Backend.setup_popup(this, 28);
            set_keep_above(true);
            set_app_paintable(true);
            
            var now = new GLib.DateTime.now_local();
            display_month = now.get_month();
            display_year = now.get_year();
            
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
            
            var now = new GLib.DateTime.now_local();
            
            // Current time display
            var time_label = new Gtk.Label(now.format("%H:%M"));
            time_label.get_style_context().add_class("calendar-time");
            content_box.pack_start(time_label, false, false, 0);
            
            var date_label = new Gtk.Label(now.format("%A, %B %e, %Y"));
            date_label.get_style_context().add_class("dim-label");
            content_box.pack_start(date_label, false, false, 0);
            
            content_box.pack_start(new Gtk.Separator(Gtk.Orientation.HORIZONTAL), false, false, 8);
            
            // Month navigation
            var nav_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            
            var prev_btn = new Gtk.Button.from_icon_name("go-previous-symbolic", Gtk.IconSize.MENU);
            prev_btn.get_style_context().add_class("flat");
            prev_btn.clicked.connect(() => {
                display_month--;
                if (display_month < 1) { display_month = 12; display_year--; }
                refresh();
            });
            nav_box.pack_start(prev_btn, false, false, 0);
            
            var month_label = new Gtk.Label(new GLib.DateTime.local(display_year, display_month, 1, 0, 0, 0).format("%B %Y"));
            month_label.get_style_context().add_class("calendar-month");
            month_label.hexpand = true;
            nav_box.pack_start(month_label, true, true, 0);
            
            var next_btn = new Gtk.Button.from_icon_name("go-next-symbolic", Gtk.IconSize.MENU);
            next_btn.get_style_context().add_class("flat");
            next_btn.clicked.connect(() => {
                display_month++;
                if (display_month > 12) { display_month = 1; display_year++; }
                refresh();
            });
            nav_box.pack_end(next_btn, false, false, 0);
            
            content_box.pack_start(nav_box, false, false, 0);
            
            // Day headers
            var days_grid = new Gtk.Grid();
            days_grid.column_homogeneous = true;
            days_grid.row_spacing = 4;
            days_grid.column_spacing = 4;
            
            string[] day_names = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" };
            for (int i = 0; i < 7; i++) {
                var day_label = new Gtk.Label(day_names[i]);
                day_label.get_style_context().add_class("calendar-day-header");
                days_grid.attach(day_label, i, 0);
            }
            
            // Calendar days
            var first_day = new GLib.DateTime.local(display_year, display_month, 1, 0, 0, 0);
            int start_dow = first_day.get_day_of_week() % 7; // Sunday = 0
            int days_in_month = get_days_in_month(display_month, display_year);
            
            int today = now.get_day_of_month();
            bool is_current_month = (display_month == now.get_month() && display_year == now.get_year());
            
            int day = 1;
            for (int row = 1; row <= 6; row++) {
                for (int col = 0; col < 7; col++) {
                    int cell = (row - 1) * 7 + col;
                    
                    if (cell < start_dow || day > days_in_month) {
                        var empty = new Gtk.Label("");
                        days_grid.attach(empty, col, row);
                    } else {
                        var day_btn = new Gtk.Label(day.to_string());
                        day_btn.set_size_request(32, 32);
                        
                        if (is_current_month && day == today) {
                            day_btn.get_style_context().add_class("calendar-today");
                        } else {
                            day_btn.get_style_context().add_class("calendar-day");
                        }
                        
                        days_grid.attach(day_btn, col, row);
                        day++;
                    }
                }
                if (day > days_in_month) break;
            }
            
            content_box.pack_start(days_grid, false, false, 0);
            content_box.show_all();
        }
        
        private int get_days_in_month(int month, int year) {
            int[] days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
            if (month == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) {
                return 29;
            }
            return days[month - 1];
        }
    }
}
