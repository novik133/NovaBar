/**
 * GlobalMenu - GTK Global Menu Widget
 * 
 * Displays application menus from GTK apps using org.gtk.Menus interface.
 * Works on both X11 and Wayland.
 */

namespace GlobalMenu {

    private struct MenuItemData {
        public string? label;
        public string? action;
        public string? section;
        public string? submenu;
    }

    public class MenuBar : Gtk.Box {
        private Gtk.Label app_label;
        private Gtk.Box menu_box;
        private Toplevel.Tracker tracker;
        private uint32 current_id;
        private bool first_update = true;
        
        private string? gtk_bus_name;
        private string? gtk_app_path;
        private string? gtk_win_path;
        
        public MenuBar() {
            Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 4);
            
            Debug.log("GlobalMenu", "Creating MenuBar...");
            
            app_label = new Gtk.Label("");
            app_label.get_style_context().add_class("globalmenu-app-name");
            pack_start(app_label, false, false, 4);
            
            menu_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            pack_start(menu_box, false, false, 0);
            
            Debug.log("GlobalMenu", "Setting up tracking...");
            // Enable tracking on both X11 and Wayland
            setup_tracking();
            
            Debug.log("GlobalMenu", "MenuBar setup complete");
            show_all();
        }
        
        public void set_panel_window(Gtk.Window panel) {
            panel.realize();
            if (panel.get_window() != null && Backend.is_x11()) {
                tracker.set_panel_id(Backend.X11.get_window_xid(panel));
            }
        }
        
        private void setup_tracking() {
            Debug.log("GlobalMenu", "Creating tracker...");
            tracker = Toplevel.create_tracker();
            Debug.log("GlobalMenu", "Connecting signal...");
            tracker.active_window_changed.connect(on_window_changed);
            Debug.log("GlobalMenu", "Starting tracker...");
            tracker.start();
            Debug.log("GlobalMenu", "Tracker started successfully");
        }
        
        private void on_window_changed(Toplevel.WindowInfo? window) {
            if (window == null) return;
            if (!first_update && window.id == current_id) return;
            first_update = false;
            
            current_id = window.id;
            app_label.set_text(window.app_id);
            
            menu_box.foreach((w) => menu_box.remove(w));
            
            if (Backend.is_x11()) {
                load_menu_x11.begin(window.id);
            } else {
                // On Wayland, title contains the D-Bus bus name
                if (window.title != null && window.title != "") {
                    load_menu_wayland.begin(window.title);
                }
            }
        }
        
        private async void load_menu_x11(uint32 xid) {
            var display = (Gdk.X11.Display)Gdk.Display.get_default();
            unowned X.Display xdisplay = display.get_xdisplay();
            
            gtk_bus_name = get_x11_string(xdisplay, xid, "_GTK_UNIQUE_BUS_NAME");
            var menu_path = get_x11_string(xdisplay, xid, "_GTK_MENUBAR_OBJECT_PATH");
            gtk_app_path = get_x11_string(xdisplay, xid, "_GTK_APPLICATION_OBJECT_PATH");
            gtk_win_path = get_x11_string(xdisplay, xid, "_GTK_WINDOW_OBJECT_PATH");
            
            var unity_path = get_x11_string(xdisplay, xid, "_UNITY_OBJECT_PATH");
            if (unity_path != null) gtk_app_path = unity_path;
            
            if (gtk_bus_name == null || menu_path == null) return;
            
            yield load_menu_from_dbus(menu_path);
        }
        
        private async void load_menu_wayland(string app_id) {
            // On Wayland, app_id might be the bus name or we need to find it
            gtk_bus_name = app_id;
            gtk_app_path = "/org/gtk/Application";
            gtk_win_path = null;
            
            // Try common menu paths
            string[] paths = {
                "/org/gtk/Application/menubar",
                "/MenuBar",
                "/org/gtk/Application/menus/menubar"
            };
            
            foreach (var path in paths) {
                if (yield try_load_menu(path)) break;
            }
        }
        
        private async bool try_load_menu(string path) {
            try {
                var conn = yield Bus.get(BusType.SESSION);
                var builder = new VariantBuilder(new VariantType("au"));
                for (uint i = 0; i < 10; i++) builder.add("u", i);
                
                var result = yield conn.call(
                    gtk_bus_name, path, "org.gtk.Menus", "Start",
                    new Variant("(au)", builder),
                    new VariantType("(a(uuaa{sv}))"),
                    DBusCallFlags.NONE, 500, null
                );
                
                build_menu(result.get_child_value(0));
                return true;
            } catch (Error e) {
                return false;
            }
        }
        
        private async void load_menu_from_dbus(string menu_path) {
            try {
                var conn = yield Bus.get(BusType.SESSION);
                var builder = new VariantBuilder(new VariantType("au"));
                for (uint i = 0; i < 10; i++) builder.add("u", i);
                
                var result = yield conn.call(
                    gtk_bus_name, menu_path, "org.gtk.Menus", "Start",
                    new Variant("(au)", builder),
                    new VariantType("(a(uuaa{sv}))"),
                    DBusCallFlags.NONE, -1, null
                );
                build_menu(result.get_child_value(0));
            } catch (Error e) {}
        }
        
        private string? get_x11_string(X.Display xdisplay, uint32 xid, string prop_name) {
            X.Atom prop = xdisplay.intern_atom(prop_name, false);
            X.Atom utf8 = xdisplay.intern_atom("UTF8_STRING", false);
            X.Atom type; int format; ulong nitems, bytes_after; char* data;
            
            Gdk.error_trap_push();
            
            if (xdisplay.get_window_property(xid, prop, 0, 1024, false, utf8,
                    out type, out format, out nitems, out bytes_after, out data) == 0) {
                if (data != null && nitems > 0) {
                    string result = ((string)data).dup();
                    X.free(data);
                    Gdk.error_trap_pop_ignored();
                    return result;
                }
            }
            if (xdisplay.get_window_property(xid, prop, 0, 1024, false, 0,
                    out type, out format, out nitems, out bytes_after, out data) == 0) {
                if (data != null && nitems > 0) {
                    string result = ((string)data).dup();
                    X.free(data);
                    Gdk.error_trap_pop_ignored();
                    return result;
                }
            }
            Gdk.error_trap_pop_ignored();
            return null;
        }
        
        private void build_menu(Variant content) {
            menu_box.foreach((w) => menu_box.remove(w));
            
            var groups = new HashTable<string, GenericArray<MenuItemData?>>(str_hash, str_equal);
            var iter = content.iterator();
            Variant? entry;
            
            while ((entry = iter.next_value()) != null) {
                uint group_id = 0, item_idx = 0;
                entry.get_child(0, "u", out group_id);
                entry.get_child(1, "u", out item_idx);
                var items = entry.get_child_value(2);
                
                string key = "%u:%u".printf(group_id, item_idx);
                var arr = new GenericArray<MenuItemData?>();
                
                var items_iter = items.iterator();
                Variant? item_dict;
                while ((item_dict = items_iter.next_value()) != null) {
                    var mi = MenuItemData();
                    Variant? v;
                    if ((v = item_dict.lookup_value("label", VariantType.STRING)) != null)
                        mi.label = v.get_string();
                    if ((v = item_dict.lookup_value("action", VariantType.STRING)) != null)
                        mi.action = v.get_string();
                    if ((v = item_dict.lookup_value(":section", VariantType.TUPLE)) != null) {
                        uint g = 0, i = 0; v.get_child(0, "u", out g); v.get_child(1, "u", out i);
                        mi.section = "%u:%u".printf(g, i);
                    }
                    if ((v = item_dict.lookup_value(":submenu", VariantType.TUPLE)) != null) {
                        uint g = 0, i = 0; v.get_child(0, "u", out g); v.get_child(1, "u", out i);
                        mi.submenu = "%u:%u".printf(g, i);
                    }
                    arr.add(mi);
                }
                groups.set(key, arr);
            }
            
            add_root_items(groups, "0:0");
            menu_box.show_all();
        }
        
        private void add_root_items(HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return;
            
            for (int i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.section != null) { add_root_items(groups, item.section); continue; }
                if (item.label == null) continue;
                
                var btn = new Gtk.MenuButton();
                btn.set_label(item.label.replace("_", ""));
                btn.get_style_context().add_class("flat");
                
                if (item.submenu != null) {
                    var submenu = build_submenu(groups, item.submenu);
                    if (submenu != null) btn.set_popup(submenu);
                }
                menu_box.pack_start(btn, false, false, 0);
            }
        }
        
        private Gtk.Menu? build_submenu(HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return null;
            var menu = new Gtk.Menu();
            add_menu_items(menu, groups, key);
            menu.show_all();
            return menu;
        }
        
        private void add_menu_items(Gtk.Menu menu, HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return;
            
            for (int i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.section != null) {
                    if (menu.get_children().length() > 0) menu.append(new Gtk.SeparatorMenuItem());
                    add_menu_items(menu, groups, item.section);
                    continue;
                }
                if (item.label == null) continue;
                
                var mi = new Gtk.MenuItem.with_label(item.label.replace("_", ""));
                if (item.submenu != null) {
                    var sub = build_submenu(groups, item.submenu);
                    if (sub != null) mi.set_submenu(sub);
                } else if (item.action != null) {
                    var action = item.action;
                    mi.activate.connect(() => activate_action(action));
                }
                menu.append(mi);
            }
        }
        
        private void activate_action(string action) {
            if (gtk_bus_name == null) return;
            
            string name; string? path;
            if (action.has_prefix("app.")) { name = action.substring(4); path = gtk_app_path; }
            else if (action.has_prefix("win.")) { name = action.substring(4); path = gtk_win_path ?? gtk_app_path; }
            else if (action.has_prefix("unity.")) { name = action.substring(6); path = gtk_app_path ?? "/org/gtk/Application"; }
            else { name = action; path = gtk_app_path; }
            
            if (path == null) return;
            
            Bus.get.begin(BusType.SESSION, null, (obj, res) => {
                try {
                    var conn = Bus.get.end(res);
                    var builder = new VariantBuilder(new VariantType("av"));
                    var platform = new VariantBuilder(new VariantType("a{sv}"));
                    conn.call.begin(gtk_bus_name, path, "org.gtk.Actions", "Activate",
                        new Variant("(sava{sv})", name, builder, platform), null, DBusCallFlags.NONE, -1, null);
                } catch (Error e) {}
            });
        }
    }
}
