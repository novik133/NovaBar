/**
 * GlobalMenu - GTK Global Menu Widget
 * 
 * Displays application menus in the NovaBar panel.  Supports two protocols:
 *   1. org.gtk.Menus   – native GTK3/4 menu model (read from X11 window
 *      properties _GTK_UNIQUE_BUS_NAME / _GTK_MENUBAR_OBJECT_PATH)
 *   2. com.canonical.dbusmenu – used by apps with appmenu-gtk-module,
 *      Qt/KDE apps, Electron apps, LibreOffice, etc.  Registrations arrive
 *      via the AppMenu Registrar that NovaBar hosts.
 *
 * Works on both X11 and Wayland.
 */

namespace GlobalMenu {

    private struct MenuItemData {
        public string? label;
        public string? action;
        public string? section;
        public string? submenu;
    }

    /**
     * Which protocol was used to load the current menu
     */
    private enum MenuSource {
        NONE,
        GTK_MENUS,
        DBUSMENU
    }

    public class MenuBar : Gtk.Box {
        private Gtk.Label app_label;
        private Gtk.Box menu_box;
        private Toplevel.Tracker tracker;
        private uint32 current_id;
        private bool first_update = true;
        
        // org.gtk.Menus state
        private string? gtk_bus_name;
        private string? gtk_app_path;
        private string? gtk_win_path;
        
        // com.canonical.dbusmenu state
        private DBusMenuClient? dbusmenu_client;
        private MenuSource current_source;
        
        public MenuBar() {
            Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 4);
            
            Debug.log("GlobalMenu", "Creating MenuBar...");
            
            app_label = new Gtk.Label("");
            app_label.get_style_context().add_class("globalmenu-app-name");
            pack_start(app_label, false, false, 4);
            
            menu_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            pack_start(menu_box, false, false, 0);
            
            current_source = MenuSource.NONE;
            
            // Start the AppMenu Registrar so apps can register their menus
            Registrar.get_instance().start();
            
            Debug.log("GlobalMenu", "Setting up tracking...");
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
            
            // Disconnect previous dbusmenu client
            if (dbusmenu_client != null) {
                dbusmenu_client.disconnect_from_menu();
                dbusmenu_client = null;
            }
            current_source = MenuSource.NONE;
            
            menu_box.foreach((w) => menu_box.remove(w));
            
            if (Backend.is_x11()) {
                load_menu_x11.begin(window.id);
            } else {
                if (window.title != null && window.title != "") {
                    load_menu_wayland.begin(window.title);
                }
            }
        }
        
        // ========== X11 Menu Loading ==========
        
        private async void load_menu_x11(uint32 xid) {
            var display = (Gdk.X11.Display)Gdk.Display.get_default();
            unowned X.Display xdisplay = display.get_xdisplay();
            
            // Strategy 1: Check the AppMenu Registrar for a dbusmenu registration
            var reg = Registrar.get_instance().get_menu_for_window(xid);
            if (reg != null && reg.bus_name != "" && reg.object_path != "/") {
                debug("GlobalMenu: Found registrar entry for window %u: %s %s",
                      xid, reg.bus_name, reg.object_path);
                if (yield load_dbusmenu(reg.bus_name, reg.object_path)) {
                    return;
                }
            }
            
            // Strategy 2: Try org.gtk.Menus via X11 window properties
            gtk_bus_name = get_x11_string(xdisplay, xid, "_GTK_UNIQUE_BUS_NAME");
            var menu_path = get_x11_string(xdisplay, xid, "_GTK_MENUBAR_OBJECT_PATH");
            gtk_app_path = get_x11_string(xdisplay, xid, "_GTK_APPLICATION_OBJECT_PATH");
            gtk_win_path = get_x11_string(xdisplay, xid, "_GTK_WINDOW_OBJECT_PATH");
            
            var unity_path = get_x11_string(xdisplay, xid, "_UNITY_OBJECT_PATH");
            if (unity_path != null) gtk_app_path = unity_path;
            
            if (gtk_bus_name != null && menu_path != null) {
                debug("GlobalMenu: Loading org.gtk.Menus for window %u: %s %s",
                      xid, gtk_bus_name, menu_path);
                yield load_gtk_menu_from_dbus(menu_path);
                if (current_source == MenuSource.GTK_MENUS) return;
            }
            
            // Strategy 2b: If we have a GTK bus name and app path but no
            // explicit menubar path, try common GMenuModel menubar locations.
            // This handles native GtkApplication apps (Thunar, gedit, etc.)
            if (gtk_bus_name != null && current_source == MenuSource.NONE) {
                string[] gtk_menu_paths = {};
                if (gtk_app_path != null) {
                    gtk_menu_paths += gtk_app_path + "/menus/menubar";
                    gtk_menu_paths += gtk_app_path + "/menubar";
                }
                gtk_menu_paths += "/org/gtk/Application/menubar";
                gtk_menu_paths += "/org/gtk/Application/menus/menubar";
                gtk_menu_paths += "/MenuBar";
                foreach (var path in gtk_menu_paths) {
                    if (yield try_load_gtk_menu(path)) return;
                }
            }
            
            // Strategy 3: If we have a GTK bus name but no menubar path,
            // try common dbusmenu object paths
            if (gtk_bus_name != null) {
                string[] dbusmenu_paths = {
                    "/com/canonical/dbusmenu",
                    "/MenuBar",
                    "/org/ayatana/NotificationItem/%s/Menu".printf(
                        gtk_bus_name.replace(":", "_").replace(".", "_"))
                };
                foreach (var path in dbusmenu_paths) {
                    if (yield load_dbusmenu(gtk_bus_name, path)) return;
                }
            }
            
            // Strategy 4: Try to find the app's PID and scan for dbusmenu
            // registrations by bus name matching
            var pid_str = get_x11_string(xdisplay, xid, "_NET_WM_PID");
            if (pid_str == null) {
                // Try as cardinal
                X.Atom prop = xdisplay.intern_atom("_NET_WM_PID", false);
                X.Atom type; int format; ulong nitems, bytes_after; char* data;
                Gdk.error_trap_push();
                if (xdisplay.get_window_property(xid, prop, 0, 1, false, X.XA_CARDINAL,
                        out type, out format, out nitems, out bytes_after, out data) == 0) {
                    if (data != null && nitems > 0) {
                        uint32 pid = *((uint32*)data);
                        X.free(data);
                        Gdk.error_trap_pop_ignored();
                        yield try_find_dbusmenu_by_pid(pid);
                        return;
                    }
                }
                Gdk.error_trap_pop_ignored();
            }
        }
        
        private async void load_menu_wayland(string app_id) {
            gtk_bus_name = app_id;
            gtk_app_path = "/org/gtk/Application";
            gtk_win_path = null;
            
            // Try dbusmenu first
            string[] dbusmenu_paths = {
                "/com/canonical/dbusmenu",
                "/MenuBar"
            };
            foreach (var path in dbusmenu_paths) {
                if (yield load_dbusmenu(app_id, path)) return;
            }
            
            // Fall back to org.gtk.Menus
            string[] gtk_paths = {
                "/org/gtk/Application/menubar",
                "/MenuBar",
                "/org/gtk/Application/menus/menubar"
            };
            foreach (var path in gtk_paths) {
                if (yield try_load_gtk_menu(path)) break;
            }
        }
        
        // ========== com.canonical.dbusmenu Loading ==========
        
        private async bool load_dbusmenu(string bus_name, string object_path) {
            var client = new DBusMenuClient(bus_name, object_path);
            var root = yield client.get_layout();
            
            if (root == null || root.children.length == 0) {
                return false;
            }
            
            debug("GlobalMenu: Loaded dbusmenu from %s %s (%u top-level items)",
                  bus_name, object_path, root.children.length);
            
            // Store client for event sending and layout updates
            dbusmenu_client = client;
            current_source = MenuSource.DBUSMENU;
            
            // Connect layout change signal
            client.layout_changed.connect(on_dbusmenu_layout_changed);
            yield client.connect_to_menu();
            
            // Build the menu bar from the dbusmenu tree
            build_dbusmenu(root);
            return true;
        }
        
        private void on_dbusmenu_layout_changed() {
            // Re-fetch layout when the app updates its menu
            if (dbusmenu_client != null) {
                dbusmenu_client.get_layout.begin((obj, res) => {
                    var root = dbusmenu_client.get_layout.end(res);
                    if (root != null && root.children.length > 0) {
                        build_dbusmenu(root);
                    }
                });
            }
        }
        
        private void build_dbusmenu(DBusMenuItem root) {
            menu_box.foreach((w) => menu_box.remove(w));
            
            for (uint i = 0; i < root.children.length; i++) {
                var child = root.children[i];
                if (!child.visible || child.is_separator()) continue;
                if (child.label == null || child.label == "") continue;
                
                var btn = new Gtk.MenuButton();
                btn.set_label(clean_label(child.label));
                btn.get_style_context().add_class("flat");
                btn.get_style_context().add_class("globalmenu-item");
                
                if (child.has_submenu()) {
                    var item_id = child.id;
                    var submenu = build_dbusmenu_submenu(child);
                    btn.set_popup(submenu);
                    
                    // Send AboutToShow when the button is clicked
                    btn.toggled.connect(() => {
                        if (btn.active && dbusmenu_client != null) {
                            dbusmenu_client.about_to_show.begin(item_id, (obj, res) => {
                                bool needs_update = dbusmenu_client.about_to_show.end(res);
                                if (needs_update) {
                                    // Re-fetch and rebuild this submenu
                                    dbusmenu_client.get_layout.begin((obj2, res2) => {
                                        var new_root = dbusmenu_client.get_layout.end(res2);
                                        if (new_root != null) {
                                            // Find the matching child and rebuild
                                            for (uint j = 0; j < new_root.children.length; j++) {
                                                if (new_root.children[j].id == item_id) {
                                                    var new_sub = build_dbusmenu_submenu(new_root.children[j]);
                                                    btn.set_popup(new_sub);
                                                    break;
                                                }
                                            }
                                        }
                                    });
                                }
                            });
                        }
                    });
                }
                
                menu_box.pack_start(btn, false, false, 0);
            }
            
            menu_box.show_all();
        }
        
        private Gtk.Menu build_dbusmenu_submenu(DBusMenuItem parent) {
            var menu = new Gtk.Menu();
            add_dbusmenu_items(menu, parent);
            menu.show_all();
            return menu;
        }
        
        private void add_dbusmenu_items(Gtk.Menu menu, DBusMenuItem parent) {
            bool last_was_separator = true;
            
            for (uint i = 0; i < parent.children.length; i++) {
                var child = parent.children[i];
                
                if (!child.visible) continue;
                
                if (child.is_separator()) {
                    if (!last_was_separator) {
                        menu.append(new Gtk.SeparatorMenuItem());
                        last_was_separator = true;
                    }
                    continue;
                }
                
                if (child.label == null || child.label == "") continue;
                
                Gtk.MenuItem mi;
                
                // Handle checkbox/radio items
                if (child.toggle_type == "checkmark") {
                    var check_mi = new Gtk.CheckMenuItem.with_label(clean_label(child.label));
                    check_mi.active = (child.toggle_state == 1);
                    mi = check_mi;
                } else if (child.toggle_type == "radio") {
                    var check_mi = new Gtk.CheckMenuItem.with_label(clean_label(child.label));
                    check_mi.draw_as_radio = true;
                    check_mi.active = (child.toggle_state == 1);
                    mi = check_mi;
                } else {
                    mi = new Gtk.MenuItem.with_label(clean_label(child.label));
                }
                
                mi.sensitive = child.enabled;
                
                // Add keyboard shortcut label if available
                if (child.shortcut != "") {
                    var box = mi.get_child() as Gtk.Box;
                    if (box == null) {
                        // Replace the label with a box containing label + accel
                        var label = mi.get_child() as Gtk.Label;
                        if (label != null) {
                            var label_text = label.label;
                            mi.remove(label);
                            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
                            var name_label = new Gtk.Label(label_text);
                            name_label.halign = Gtk.Align.START;
                            var accel_label = new Gtk.Label(child.shortcut);
                            accel_label.halign = Gtk.Align.END;
                            accel_label.get_style_context().add_class("dim-label");
                            hbox.pack_start(name_label, true, true, 0);
                            hbox.pack_end(accel_label, false, false, 0);
                            mi.add(hbox);
                        }
                    }
                }
                
                if (child.has_submenu()) {
                    var sub = build_dbusmenu_submenu(child);
                    mi.set_submenu(sub);
                } else {
                    var item_id = child.id;
                    mi.activate.connect(() => {
                        if (dbusmenu_client != null) {
                            dbusmenu_client.send_event.begin(item_id);
                        }
                    });
                }
                
                menu.append(mi);
                last_was_separator = false;
            }
        }
        
        // ========== org.gtk.Menus Loading ==========
        
        private async bool try_load_gtk_menu(string path) {
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
                
                build_gtk_menu(result.get_child_value(0));
                current_source = MenuSource.GTK_MENUS;
                return true;
            } catch (Error e) {
                return false;
            }
        }
        
        private async void load_gtk_menu_from_dbus(string menu_path) {
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
                var content = result.get_child_value(0);
                debug("GlobalMenu: org.gtk.Menus returned %zu entries from %s %s",
                      content.n_children(), gtk_bus_name, menu_path);
                build_gtk_menu(content);
                current_source = MenuSource.GTK_MENUS;
            } catch (Error e) {
                debug("GlobalMenu: org.gtk.Menus load failed for %s %s: %s",
                      gtk_bus_name, menu_path, e.message);
            }
        }
        
        // ========== org.gtk.Menus Building ==========
        
        private void build_gtk_menu(Variant content) {
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
            
            add_gtk_root_items(groups, "0:0");
            menu_box.show_all();
        }
        
        private void add_gtk_root_items(HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return;
            
            for (int i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.section != null) { add_gtk_root_items(groups, item.section); continue; }
                if (item.label == null) continue;
                
                var btn = new Gtk.MenuButton();
                btn.set_label(clean_label(item.label));
                btn.get_style_context().add_class("flat");
                btn.get_style_context().add_class("globalmenu-item");
                
                if (item.submenu != null) {
                    var submenu = build_gtk_submenu(groups, item.submenu);
                    if (submenu != null) btn.set_popup(submenu);
                }
                menu_box.pack_start(btn, false, false, 0);
            }
        }
        
        private Gtk.Menu? build_gtk_submenu(HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return null;
            var menu = new Gtk.Menu();
            add_gtk_menu_items(menu, groups, key);
            menu.show_all();
            return menu;
        }
        
        private void add_gtk_menu_items(Gtk.Menu menu, HashTable<string, GenericArray<MenuItemData?>> groups, string key) {
            var items = groups.lookup(key);
            if (items == null) return;
            
            for (int i = 0; i < items.length; i++) {
                var item = items[i];
                if (item.section != null) {
                    if (menu.get_children().length() > 0) menu.append(new Gtk.SeparatorMenuItem());
                    add_gtk_menu_items(menu, groups, item.section);
                    continue;
                }
                if (item.label == null) continue;
                
                var mi = new Gtk.MenuItem.with_label(clean_label(item.label));
                if (item.submenu != null) {
                    var sub = build_gtk_submenu(groups, item.submenu);
                    if (sub != null) mi.set_submenu(sub);
                } else if (item.action != null) {
                    var action = item.action;
                    mi.activate.connect(() => activate_gtk_action(action));
                }
                menu.append(mi);
            }
        }
        
        // ========== Action Dispatch ==========
        
        private void activate_gtk_action(string action) {
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
        
        // ========== PID-based dbusmenu discovery ==========
        
        private async void try_find_dbusmenu_by_pid(uint32 pid) {
            // Try to find a D-Bus bus name owned by this PID and check for dbusmenu
            try {
                var conn = yield Bus.get(BusType.SESSION);
                
                // Get the list of all bus names
                var result = yield conn.call(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    "ListNames",
                    null,
                    new VariantType("(as)"),
                    DBusCallFlags.NONE,
                    1000,
                    null
                );
                
                var names_variant = result.get_child_value(0);
                for (size_t i = 0; i < names_variant.n_children(); i++) {
                    var name = names_variant.get_child_value(i).get_string();
                    if (name.has_prefix(":")) continue; // skip unique names for speed
                    
                    try {
                        var pid_result = yield conn.call(
                            "org.freedesktop.DBus",
                            "/org/freedesktop/DBus",
                            "org.freedesktop.DBus",
                            "GetConnectionUnixProcessID",
                            new Variant("(s)", name),
                            new VariantType("(u)"),
                            DBusCallFlags.NONE,
                            500,
                            null
                        );
                        uint32 conn_pid = 0;
                        pid_result.get("(u)", out conn_pid);
                        
                        if (conn_pid == pid) {
                            // Try dbusmenu on common paths
                            if (yield load_dbusmenu(name, "/com/canonical/dbusmenu")) return;
                            if (yield load_dbusmenu(name, "/MenuBar")) return;
                        }
                    } catch (Error e) {
                        // Skip names we can't query
                    }
                }
            } catch (Error e) {
                debug("GlobalMenu: PID-based discovery failed: %s", e.message);
            }
        }
        
        // ========== Helpers ==========
        
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
        
        /**
         * Remove mnemonics underscores from labels
         */
        private string clean_label(string label) {
            return label.replace("_", "");
        }
    }
}
