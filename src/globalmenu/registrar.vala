/**
 * AppMenu Registrar - D-Bus service for com.canonical.AppMenu.Registrar
 *
 * GTK apps with appmenu-gtk-module loaded call RegisterWindow(uint32 windowId,
 * objectPath) on this service to announce that they export a dbusmenu at the
 * given object path on their own bus name.  We store those registrations and
 * expose a GetMenuForWindow method so the global menu bar can look them up.
 */

namespace GlobalMenu {

    /**
     * Registration entry for a window's menu
     */
    public struct MenuRegistration {
        public uint32 window_id;
        public string bus_name;
        public string object_path;
    }

    /**
     * The Registrar singleton – owns the well-known bus name and implements
     * the com.canonical.AppMenu.Registrar interface.
     */
    public class Registrar : Object {
        private static Registrar? _instance = null;

        private HashTable<uint32, MenuRegistration?> _registrations;
        private uint _bus_owner_id;
        private uint _registration_id;
        private DBusConnection? _connection;

        /**
         * Emitted when a window registers or unregisters its menu
         */
        public signal void window_registered(uint32 window_id, string bus_name, string object_path);
        public signal void window_unregistered(uint32 window_id);

        public static Registrar get_instance() {
            if (_instance == null) {
                _instance = new Registrar();
            }
            return _instance;
        }

        private Registrar() {
            _registrations = new HashTable<uint32, MenuRegistration?>(direct_hash, direct_equal);
        }

        /**
         * Start the registrar – acquire the bus name and export the object
         */
        public void start() {
            _bus_owner_id = Bus.own_name(
                BusType.SESSION,
                "com.canonical.AppMenu.Registrar",
                BusNameOwnerFlags.NONE,
                on_bus_acquired,
                on_name_acquired,
                on_name_lost
            );
        }

        /**
         * Stop the registrar
         */
        public void stop() {
            if (_registration_id > 0 && _connection != null) {
                _connection.unregister_object(_registration_id);
                _registration_id = 0;
            }
            if (_bus_owner_id > 0) {
                Bus.unown_name(_bus_owner_id);
                _bus_owner_id = 0;
            }
        }

        /**
         * Look up the menu registration for a window
         */
        public MenuRegistration? get_menu_for_window(uint32 window_id) {
            return _registrations.lookup(window_id);
        }

        // ---- D-Bus callbacks ----

        private void on_bus_acquired(DBusConnection conn, string name) {
            _connection = conn;
            try {
                _registration_id = conn.register_object(
                    "/com/canonical/AppMenu/Registrar",
                    new RegistrarSkeleton(this)
                );
                debug("Registrar: Exported on session bus");
            } catch (IOError e) {
                warning("Registrar: Failed to export object: %s", e.message);
            }
        }

        private void on_name_acquired(DBusConnection conn, string name) {
            debug("Registrar: Acquired bus name %s", name);
        }

        private void on_name_lost(DBusConnection conn, string name) {
            warning("Registrar: Lost bus name %s", name);
        }

        // ---- Methods called by the skeleton ----

        internal void register_window(uint32 window_id, string sender, string menu_object_path) {
            var reg = MenuRegistration() {
                window_id = window_id,
                bus_name = sender,
                object_path = menu_object_path
            };
            _registrations[window_id] = reg;
            debug("Registrar: Registered window %u → %s %s", window_id, sender, menu_object_path);
            window_registered(window_id, sender, menu_object_path);
        }

        internal void unregister_window(uint32 window_id) {
            _registrations.remove(window_id);
            debug("Registrar: Unregistered window %u", window_id);
            window_unregistered(window_id);
        }
    }

    /**
     * D-Bus skeleton that implements com.canonical.AppMenu.Registrar
     */
    [DBus(name = "com.canonical.AppMenu.Registrar")]
    private class RegistrarSkeleton : Object {
        private Registrar _registrar;

        public RegistrarSkeleton(Registrar registrar) {
            _registrar = registrar;
        }

        public void RegisterWindow(uint32 windowId, ObjectPath menuObjectPath, GLib.BusName sender) throws Error {
            _registrar.register_window(windowId, (string) sender, (string) menuObjectPath);
        }

        public void UnregisterWindow(uint32 windowId) throws Error {
            _registrar.unregister_window(windowId);
        }

        public void GetMenuForWindow(uint32 windowId, out string service, out ObjectPath menuObjectPath) throws Error {
            var reg = _registrar.get_menu_for_window(windowId);
            if (reg != null) {
                service = reg.bus_name;
                menuObjectPath = new ObjectPath(reg.object_path);
            } else {
                service = "";
                menuObjectPath = new ObjectPath("/");
            }
        }

        public void GetMenus(out HashTable<uint32, string> menus) throws Error {
            menus = new HashTable<uint32, string>(direct_hash, direct_equal);
            // Simplified – callers typically use GetMenuForWindow instead
        }
    }
}
