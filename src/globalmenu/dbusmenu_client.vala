/**
 * DBusMenu Client - reads menus via com.canonical.dbusmenu interface
 *
 * Applications that use appmenu-gtk-module (or Qt/Electron apps with native
 * dbusmenu support) export their menu tree through this interface.  The layout
 * is fetched with GetLayout and individual property changes are tracked via
 * the LayoutUpdated / ItemsPropertiesUpdated signals.
 */

namespace GlobalMenu {

    /**
     * Represents a single item in a dbusmenu tree
     */
    public class DBusMenuItem : Object {
        public int32 id { get; set; }
        public string label { get; set; default = ""; }
        public string item_type { get; set; default = "standard"; }
        public string toggle_type { get; set; default = ""; }
        public int32 toggle_state { get; set; default = -1; }
        public bool enabled { get; set; default = true; }
        public bool visible { get; set; default = true; }
        public string icon_name { get; set; default = ""; }
        public string shortcut { get; set; default = ""; }
        public string children_display { get; set; default = ""; }
        public GenericArray<DBusMenuItem> children { get; owned set; }

        public DBusMenuItem() {
            children = new GenericArray<DBusMenuItem>();
        }

        public bool is_separator() {
            return item_type == "separator";
        }

        public bool has_submenu() {
            return children_display == "submenu" || children.length > 0;
        }
    }

    /**
     * Client that reads a com.canonical.dbusmenu menu tree from D-Bus
     */
    public class DBusMenuClient : Object {
        private string _bus_name;
        private string _object_path;
        private DBusConnection? _connection;
        private uint _layout_signal_id;
        private uint _props_signal_id;

        /**
         * Emitted when the menu layout changes and should be re-read
         */
        public signal void layout_changed();

        public DBusMenuClient(string bus_name, string object_path) {
            _bus_name = bus_name;
            _object_path = object_path;
        }

        /**
         * Connect to the session bus and subscribe to layout change signals
         */
        public async bool connect_to_menu() {
            try {
                _connection = yield Bus.get(BusType.SESSION);

                // Subscribe to LayoutUpdated signal
                _layout_signal_id = _connection.signal_subscribe(
                    _bus_name,
                    "com.canonical.dbusmenu",
                    "LayoutUpdated",
                    _object_path,
                    null,
                    DBusSignalFlags.NONE,
                    on_layout_updated
                );

                // Subscribe to ItemsPropertiesUpdated signal
                _props_signal_id = _connection.signal_subscribe(
                    _bus_name,
                    "com.canonical.dbusmenu",
                    "ItemsPropertiesUpdated",
                    _object_path,
                    null,
                    DBusSignalFlags.NONE,
                    on_items_properties_updated
                );

                debug("DBusMenuClient: Connected to %s at %s", _bus_name, _object_path);
                return true;
            } catch (Error e) {
                warning("DBusMenuClient: Failed to connect: %s", e.message);
                return false;
            }
        }

        /**
         * Disconnect signal subscriptions
         */
        public void disconnect_from_menu() {
            if (_connection != null) {
                if (_layout_signal_id > 0) {
                    _connection.signal_unsubscribe(_layout_signal_id);
                    _layout_signal_id = 0;
                }
                if (_props_signal_id > 0) {
                    _connection.signal_unsubscribe(_props_signal_id);
                    _props_signal_id = 0;
                }
            }
        }

        /**
         * Fetch the full menu layout from the root
         */
        public async DBusMenuItem? get_layout() {
            if (_connection == null) {
                if (!(yield connect_to_menu())) {
                    return null;
                }
            }

            try {
                // GetLayout(parentId: int32, recursionDepth: int32, propertyNames: as)
                // returns (revision: uint32, layout: (ia{sv}av))
                int32 parent_id = 0;
                int32 depth = -1;
                string[] empty_props = {};
                var result = yield _connection.call(
                    _bus_name,
                    _object_path,
                    "com.canonical.dbusmenu",
                    "GetLayout",
                    new Variant("(ii^as)", parent_id, depth, empty_props),
                    new VariantType("(u(ia{sv}av))"),
                    DBusCallFlags.NONE,
                    2000,
                    null
                );

                // Parse the layout tuple
                var layout_variant = result.get_child_value(1);
                return parse_layout_item(layout_variant);

            } catch (Error e) {
                debug("DBusMenuClient: GetLayout failed for %s %s: %s",
                      _bus_name, _object_path, e.message);
                return null;
            }
        }

        /**
         * Send an Event (click) to a menu item
         */
        public async void send_event(int32 item_id, string event_type = "clicked") {
            if (_connection == null) return;

            try {
                yield _connection.call(
                    _bus_name,
                    _object_path,
                    "com.canonical.dbusmenu",
                    "Event",
                    new Variant("(isvu)", item_id, event_type,
                                new Variant.int32(0),
                                (uint32) GLib.get_real_time() / 1000),
                    null,
                    DBusCallFlags.NONE,
                    2000,
                    null
                );
            } catch (Error e) {
                debug("DBusMenuClient: Event failed: %s", e.message);
            }
        }

        /**
         * Send an AboutToShow event so the app can populate the submenu
         */
        public async bool about_to_show(int32 item_id) {
            if (_connection == null) return false;

            try {
                var result = yield _connection.call(
                    _bus_name,
                    _object_path,
                    "com.canonical.dbusmenu",
                    "AboutToShow",
                    new Variant("(i)", item_id),
                    new VariantType("(b)"),
                    DBusCallFlags.NONE,
                    2000,
                    null
                );
                bool needs_update = false;
                result.get("(b)", out needs_update);
                return needs_update;
            } catch (Error e) {
                // AboutToShow is optional — many apps don't implement it
                return false;
            }
        }

        // ---- Parsing ----

        /**
         * Parse a single layout item: (ia{sv}av)
         *   i       = item id
         *   a{sv}   = properties
         *   av      = children (each child is a variant wrapping (ia{sv}av))
         */
        private DBusMenuItem parse_layout_item(Variant item_variant) {
            var menu_item = new DBusMenuItem();

            menu_item.id = item_variant.get_child_value(0).get_int32();

            // Parse properties
            var props = item_variant.get_child_value(1);
            var props_iter = props.iterator();
            string key;
            Variant val;
            while (props_iter.next("{sv}", out key, out val)) {
                apply_property(menu_item, key, val);
            }

            // Parse children
            var children_variant = item_variant.get_child_value(2);
            for (size_t i = 0; i < children_variant.n_children(); i++) {
                var child_wrapper = children_variant.get_child_value(i);
                // Each child is a Variant wrapping (ia{sv}av)
                var child_inner = child_wrapper.get_variant();
                var child_item = parse_layout_item(child_inner);
                menu_item.children.add(child_item);
            }

            return menu_item;
        }

        private void apply_property(DBusMenuItem item, string key, Variant val) {
            switch (key) {
                case "label":
                    item.label = val.get_string();
                    break;
                case "type":
                    item.item_type = val.get_string();
                    break;
                case "toggle-type":
                    item.toggle_type = val.get_string();
                    break;
                case "toggle-state":
                    item.toggle_state = val.get_int32();
                    break;
                case "enabled":
                    item.enabled = val.get_boolean();
                    break;
                case "visible":
                    item.visible = val.get_boolean();
                    break;
                case "icon-name":
                    item.icon_name = val.get_string();
                    break;
                case "shortcut":
                    item.shortcut = format_shortcut(val);
                    break;
                case "children-display":
                    item.children_display = val.get_string();
                    break;
            }
        }

        private string format_shortcut(Variant val) {
            // shortcut is aas — array of arrays of strings
            // e.g. [["Control", "s"]]
            var sb = new StringBuilder();
            for (size_t i = 0; i < val.n_children(); i++) {
                var combo = val.get_child_value(i);
                for (size_t j = 0; j < combo.n_children(); j++) {
                    if (sb.len > 0) sb.append("+");
                    sb.append(combo.get_child_value(j).get_string());
                }
            }
            return sb.str;
        }

        // ---- Signal handlers ----

        private void on_layout_updated(
            DBusConnection conn, string? sender, string path,
            string iface, string signal_name, Variant parameters
        ) {
            debug("DBusMenuClient: LayoutUpdated from %s", _bus_name);
            layout_changed();
        }

        private void on_items_properties_updated(
            DBusConnection conn, string? sender, string path,
            string iface, string signal_name, Variant parameters
        ) {
            debug("DBusMenuClient: ItemsPropertiesUpdated from %s", _bus_name);
            layout_changed();
        }
    }
}
