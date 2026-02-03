/**
 * Notification Daemon - Shows notifications as popups from top-right
 */

namespace Indicators {

    [DBus (name = "org.freedesktop.Notifications")]
    public class NotificationServer : Object {
        private uint32 id_counter = 0;
        private weak NotificationManager manager;
        
        public NotificationServer(NotificationManager mgr) {
            this.manager = mgr;
        }
        
        public string[] get_capabilities() throws Error {
            return { "body", "actions", "icon-static" };
        }
        
        public uint32 notify(string app_name, uint32 replaces_id, string app_icon,
                            string summary, string body, string[] actions,
                            HashTable<string, Variant> hints, int expire_timeout) throws Error {
            uint32 id = replaces_id > 0 ? replaces_id : ++id_counter;
            manager.show_notification(id, app_name, app_icon, summary, body, 5000);
            return id;
        }
        
        public void close_notification(uint32 id) throws Error {
            manager.close_notification(id);
        }
        
        public void get_server_information(out string name, out string vendor,
                                           out string version, out string spec_version) throws Error {
            name = "NovaOS";
            vendor = "NovaOS";
            version = "1.0";
            spec_version = "1.2";
        }
        
        public signal void notification_closed(uint32 id, uint32 reason);
        public signal void action_invoked(uint32 id, string action_key);
    }
    
    public class NotificationManager : Object {
        private int panel_height = 28;
        private GenericArray<NotificationPopup> popups;
        
        public NotificationManager() {
            popups = new GenericArray<NotificationPopup>();
        }
        
        public void show_notification(uint32 id, string app_name, string icon,
                                      string summary, string body, int timeout) {
            var popup = new NotificationPopup(id, app_name, icon, summary, body);
            popup.closed.connect(() => on_popup_closed(popup));
            popups.add(popup);
            position_popups();
            popup.show_all();
            
            if (timeout > 0) {
                Timeout.add(timeout, () => {
                    popup.close();
                    return false;
                });
            }
        }
        
        public void close_notification(uint32 id) {
            for (int i = 0; i < popups.length; i++) {
                if (popups[i].id == id) {
                    popups[i].close();
                    break;
                }
            }
        }
        
        private void on_popup_closed(NotificationPopup popup) {
            for (int i = 0; i < popups.length; i++) {
                if (popups[i] == popup) {
                    popups.remove_index(i);
                    break;
                }
            }
            position_popups();
        }
        
        private void position_popups() {
            var display = Gdk.Display.get_default();
            var monitor = display.get_primary_monitor() ?? display.get_monitor(0);
            var geom = monitor.get_geometry();
            
            int x = geom.x + geom.width - 360;
            int y = geom.y + panel_height + 8;
            
            for (int i = 0; i < popups.length; i++) {
                if (Backend.is_x11()) {
                    popups[i].move(x, y);
                }
                // On Wayland, notifications use layer-shell positioning set in constructor
                int w, h;
                popups[i].get_size(out w, out h);
                y += h + 8;
            }
        }
    }
    
    private class NotificationPopup : Gtk.Window {
        public uint32 id { get; private set; }
        public signal void closed();
        
        public NotificationPopup(uint32 id, string app_name, string icon_name,
                                 string summary, string body) {
            Object(type: Gtk.WindowType.POPUP);
            this.id = id;
            
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
                cr.set_source_rgba(0.2, 0.2, 0.2, 0.95);
                cr.fill_preserve();
                cr.set_source_rgba(1, 1, 1, 0.1);
                cr.set_line_width(1);
                cr.stroke();
                return false;
            });
            
            var main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            
            // Close button on left
            var close_btn = new Gtk.Button();
            close_btn.get_style_context().add_class("flat");
            close_btn.get_style_context().add_class("notification-close");
            close_btn.add(new Gtk.Image.from_icon_name("window-close-symbolic", Gtk.IconSize.MENU));
            close_btn.valign = Gtk.Align.START;
            close_btn.clicked.connect(() => this.close());
            main_box.pack_start(close_btn, false, false, 4);
            
            var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
            content.margin = 8;
            content.margin_start = 0;
            content.set_size_request(300, -1);
            
            // App icon
            if (icon_name != "") {
                var img = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.DND);
                content.pack_start(img, false, false, 0);
            }
            
            // Text
            var text_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            text_box.hexpand = true;
            
            var title = new Gtk.Label(summary);
            title.get_style_context().add_class("notification-title");
            title.halign = Gtk.Align.START;
            title.ellipsize = Pango.EllipsizeMode.END;
            title.max_width_chars = 30;
            text_box.pack_start(title, false, false, 0);
            
            if (body != "") {
                var body_label = new Gtk.Label(body);
                body_label.get_style_context().add_class("notification-body");
                body_label.halign = Gtk.Align.START;
                body_label.ellipsize = Pango.EllipsizeMode.END;
                body_label.max_width_chars = 35;
                body_label.lines = 2;
                body_label.wrap = true;
                text_box.pack_start(body_label, false, false, 0);
            }
            
            content.pack_start(text_box, true, true, 0);
            main_box.pack_start(content, true, true, 0);
            
            add(main_box);
        }
        
        public new void close() {
            closed();
            destroy();
        }
    }
    
    // Dummy widget to add to panel (invisible, just starts the daemon)
    public class Notifications : Gtk.Box {
        private static NotificationServer? server;
        private static NotificationManager? manager;
        
        public Notifications() {
            // Don't show anything
            no_show_all = true;
            
            if (server == null) {
                manager = new NotificationManager();
                server = new NotificationServer(manager);
                
                Bus.own_name(BusType.SESSION, "org.freedesktop.Notifications",
                    BusNameOwnerFlags.REPLACE,
                    (conn) => {
                        try {
                            conn.register_object("/org/freedesktop/Notifications", server);
                        } catch (Error e) {
                            warning("Could not register notification server: %s", e.message);
                        }
                    },
                    () => {},
                    () => warning("Could not acquire notification bus name")
                );
            }
        }
    }
}
