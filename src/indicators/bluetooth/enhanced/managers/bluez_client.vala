/**
 * Enhanced Bluetooth Indicator - BlueZ D-Bus Client
 * 
 * This file provides a comprehensive wrapper around BlueZ's D-Bus API,
 * handling client initialization, connection management, object management,
 * and signal processing for the enhanced Bluetooth indicator system.
 */

using GLib;

namespace EnhancedBluetooth {

    /**
     * BlueZ D-Bus client providing low-level communication with BlueZ daemon
     * 
     * This class manages D-Bus connections, object proxies, signal subscriptions,
     * and provides a robust interface for Bluetooth operations with automatic
     * reconnection and error handling.
     */
    public class BlueZClient : GLib.Object {
        // D-Bus constants
        private const string BLUEZ_SERVICE = "org.bluez";
        private const string OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager";
        private const string PROPERTIES_INTERFACE = "org.freedesktop.DBus.Properties";
        private const string ADAPTER_INTERFACE = "org.bluez.Adapter1";
        private const string DEVICE_INTERFACE = "org.bluez.Device1";
        private const string AGENT_MANAGER_INTERFACE = "org.bluez.AgentManager1";
        
        // Connection management
        private DBusConnection? _connection;
        private DBusObjectManagerClient? _object_manager;
        private bool _is_connected;
        private uint _name_watch_id;
        
        // Proxy management
        private HashTable<string, DBusProxy> _proxies;
        
        // Signal subscription management
        private HashTable<uint, SignalSubscription> _signal_subscriptions;
        private uint _next_subscription_id;
        
        // Reconnection management
        private uint _reconnect_timeout_id;
        private int _reconnect_attempts;
        private const int MAX_RECONNECT_ATTEMPTS = 10;
        private const int BASE_RECONNECT_DELAY_MS = 1000;
        private const int MAX_RECONNECT_DELAY_MS = 30000;
        
        /**
         * Signal emitted when a BlueZ object is added
         */
        public signal void object_added(string object_path, string interface_name);
        
        /**
         * Signal emitted when a BlueZ object is removed
         */
        public signal void object_removed(string object_path, string interface_name);
        
        /**
         * Signal emitted when object properties change
         */
        public signal void properties_changed(string object_path, string interface_name, HashTable<string, Variant> changed_properties);
        
        /**
         * Signal emitted when connection state changes
         */
        public signal void connection_state_changed(bool connected);
        
        /**
         * Whether the client is connected to BlueZ
         */
        public bool is_connected { 
            get { return _is_connected; } 
        }
        
        /**
         * Constructor
         */
        public BlueZClient() {
            _is_connected = false;
            _proxies = new HashTable<string, DBusProxy>(str_hash, str_equal);
            _signal_subscriptions = new HashTable<uint, SignalSubscription>(direct_hash, direct_equal);
            _next_subscription_id = 1;
            _reconnect_attempts = 0;
        }
        
        /**
         * Initialize the BlueZ D-Bus client asynchronously
         * 
         * @return true if initialization was successful
         */
        public async bool initialize() {
            try {
                debug("BlueZClient: Initializing BlueZ D-Bus client...");
                
                // Connect to system bus
                if (!yield connect_to_bluez()) {
                    return false;
                }
                
                // Setup object manager
                if (!yield setup_object_manager()) {
                    return false;
                }
                
                // Setup name monitoring
                setup_name_watch();
                
                _is_connected = true;
                _reconnect_attempts = 0;
                debug("BlueZClient: BlueZ D-Bus client initialized successfully");
                connection_state_changed(true);
                
                return true;
                
            } catch (Error e) {
                warning("BlueZClient: Failed to initialize: %s", e.message);
                _is_connected = false;
                connection_state_changed(false);
                
                // Schedule reconnection
                schedule_reconnect();
                
                return false;
            }
        }
        
        /**
         * Shutdown the BlueZ D-Bus client
         */
        public void shutdown() {
            debug("BlueZClient: Shutting down BlueZ D-Bus client...");
            
            // Cancel reconnection attempts
            if (_reconnect_timeout_id > 0) {
                Source.remove(_reconnect_timeout_id);
                _reconnect_timeout_id = 0;
            }
            
            // Unsubscribe from all signals
            _signal_subscriptions.remove_all();
            
            // Clear proxies
            _proxies.remove_all();
            
            // Stop name watch
            if (_name_watch_id > 0) {
                Bus.unwatch_name(_name_watch_id);
                _name_watch_id = 0;
            }
            
            // Clear object manager
            _object_manager = null;
            
            // Clear connection
            _connection = null;
            
            _is_connected = false;
            connection_state_changed(false);
            
            debug("BlueZClient: Shutdown complete");
        }
        
        /**
         * Connect to BlueZ D-Bus service
         */
        private async bool connect_to_bluez() throws Error {
            debug("BlueZClient: Connecting to system D-Bus...");
            
            _connection = yield Bus.get(BusType.SYSTEM);
            
            if (_connection == null) {
                throw new IOError.NOT_CONNECTED("Failed to connect to system D-Bus");
            }
            
            // Note: DBusConnection.closed is a property, not a signal in older GLib versions
            // We'll handle connection loss through name watch instead
            
            debug("BlueZClient: Connected to system D-Bus");
            return true;
        }
        
        /**
         * Setup object manager for BlueZ objects
         */
        private async bool setup_object_manager() throws Error {
            debug("BlueZClient: Setting up object manager...");
            
            try {
                _object_manager = yield new DBusObjectManagerClient(
                    _connection,
                    DBusObjectManagerClientFlags.NONE,
                    BLUEZ_SERVICE,
                    "/",
                    null,
                    null
                );
                
                if (_object_manager == null) {
                    throw new IOError.FAILED("Failed to create object manager");
                }
                
                // Connect to object manager signals
                _object_manager.interface_added.connect(on_interface_added);
                _object_manager.interface_removed.connect(on_interface_removed);
                _object_manager.object_added.connect(on_object_added);
                _object_manager.object_removed.connect(on_object_removed);
                
                // Subscribe to PropertiesChanged globally so property updates
                // (e.g. Discovering, Connected) are forwarded to managers even
                // without explicitly creating proxies via get_proxy().
                _connection.signal_subscribe(
                    BLUEZ_SERVICE,
                    PROPERTIES_INTERFACE,
                    "PropertiesChanged",
                    null,   // all object paths
                    null,
                    DBusSignalFlags.NONE,
                    on_dbus_properties_changed
                );
                
                debug("BlueZClient: Object manager setup complete");
                return true;
                
            } catch (Error e) {
                warning("BlueZClient: Failed to setup object manager: %s", e.message);
                throw e;
            }
        }
        
        /**
         * Setup name watch to detect BlueZ availability
         */
        private void setup_name_watch() {
            debug("BlueZClient: Setting up name watch for %s...", BLUEZ_SERVICE);
            
            _name_watch_id = Bus.watch_name(
                BusType.SYSTEM,
                BLUEZ_SERVICE,
                BusNameWatcherFlags.NONE,
                on_name_appeared,
                on_name_vanished
            );
        }
        
        /**
         * Handle BlueZ service appearing on D-Bus
         */
        private void on_name_appeared(DBusConnection connection, string name, string name_owner) {
            debug("BlueZClient: BlueZ service appeared: %s (owner: %s)", name, name_owner);
            
            if (!_is_connected) {
                // Attempt to reconnect
                initialize.begin();
            }
        }
        
        /**
         * Handle BlueZ service vanishing from D-Bus
         */
        private void on_name_vanished(DBusConnection connection, string name) {
            warning("BlueZClient: BlueZ service vanished: %s", name);
            
            if (_is_connected) {
                _is_connected = false;
                connection_state_changed(false);
                
                // Clear cached data
                _proxies.remove_all();
                
                // Schedule reconnection
                schedule_reconnect();
            }
        }
        
        /**
         * Schedule reconnection with exponential backoff
         */
        private void schedule_reconnect() {
            // Cancel existing reconnection attempt
            if (_reconnect_timeout_id > 0) {
                Source.remove(_reconnect_timeout_id);
                _reconnect_timeout_id = 0;
            }
            
            if (_reconnect_attempts >= MAX_RECONNECT_ATTEMPTS) {
                warning("BlueZClient: Maximum reconnection attempts reached (%d)", MAX_RECONNECT_ATTEMPTS);
                return;
            }
            
            // Calculate delay with exponential backoff
            int delay_ms = BASE_RECONNECT_DELAY_MS * (1 << _reconnect_attempts);
            if (delay_ms > MAX_RECONNECT_DELAY_MS) {
                delay_ms = MAX_RECONNECT_DELAY_MS;
            }
            
            _reconnect_attempts++;
            
            debug("BlueZClient: Scheduling reconnection attempt %d in %d ms", 
                  _reconnect_attempts, delay_ms);
            
            _reconnect_timeout_id = Timeout.add(delay_ms, () => {
                _reconnect_timeout_id = 0;
                initialize.begin();
                return Source.REMOVE;
            });
        }
        
        /**
         * Handle interface added to object
         */
        private void on_interface_added(DBusObject object, DBusInterface interface_obj) {
            var object_path = object.get_object_path();
            string interface_name;
            var info = interface_obj.get_info();
            if (info != null) {
                interface_name = info.name;
            } else if (interface_obj is DBusProxy) {
                interface_name = ((DBusProxy) interface_obj).get_interface_name();
            } else {
                return;
            }
            
            debug("BlueZClient: Interface added: %s on %s", interface_name, object_path);
            
            // Remove cached proxy if exists
            string proxy_key = @"$object_path:$interface_name";
            _proxies.remove(proxy_key);
            
            object_added(object_path, interface_name);
        }
        
        /**
         * Handle interface removed from object
         */
        private void on_interface_removed(DBusObject object, DBusInterface interface_obj) {
            var object_path = object.get_object_path();
            string interface_name;
            var info = interface_obj.get_info();
            if (info != null) {
                interface_name = info.name;
            } else if (interface_obj is DBusProxy) {
                interface_name = ((DBusProxy) interface_obj).get_interface_name();
            } else {
                return;
            }
            
            debug("BlueZClient: Interface removed: %s from %s", interface_name, object_path);
            
            // Remove cached proxy
            string proxy_key = @"$object_path:$interface_name";
            _proxies.remove(proxy_key);
            
            object_removed(object_path, interface_name);
        }
        
        /**
         * Handle object added — enumerate all interfaces and emit object_added
         * for each one. When BlueZ adds a new device during discovery, the object
         * arrives with all its interfaces at once (Device1, MediaControl1, etc.).
         * on_interface_added only fires for interfaces added AFTER the object exists,
         * so we must handle the initial set here.
         */
        private void on_object_added(DBusObject object) {
            var object_path = object.get_object_path();
            debug("BlueZClient: Object added: %s", object_path);
            
            var interfaces = object.get_interfaces();
            foreach (var interface_obj in interfaces) {
                string? iface_name = null;
                var info = interface_obj.get_info();
                if (info != null) {
                    iface_name = info.name;
                } else if (interface_obj is DBusProxy) {
                    iface_name = ((DBusProxy) interface_obj).get_interface_name();
                }
                if (iface_name != null) {
                    debug("BlueZClient: Object added interface: %s on %s", iface_name, object_path);
                    object_added(object_path, iface_name);
                }
            }
        }
        
        /**
         * Handle object removed
         */
        private void on_object_removed(DBusObject object) {
            var object_path = object.get_object_path();
            debug("BlueZClient: Object removed: %s", object_path);
            
            // Remove all cached proxies for this object
            var keys_to_remove = new GenericArray<string>();
            _proxies.foreach((key, value) => {
                if (key.has_prefix(object_path + ":")) {
                    keys_to_remove.add(key);
                }
            });
            for (uint i = 0; i < keys_to_remove.length; i++) {
                _proxies.remove(keys_to_remove[i]);
            }
        }

        
        /**
         * Get a D-Bus proxy for the specified object and interface
         * 
         * @param object_path The D-Bus object path
         * @param interface_name The D-Bus interface name
         * @return The D-Bus proxy
         */
        public async DBusProxy get_proxy(string object_path, string interface_name) throws Error {
            if (!_is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            // Check cache first
            string proxy_key = @"$object_path:$interface_name";
            var cached_proxy = _proxies.lookup(proxy_key);
            if (cached_proxy != null) {
                return cached_proxy;
            }
            
            // Create new proxy
            try {
                var proxy = yield new DBusProxy(
                    _connection,
                    DBusProxyFlags.NONE,
                    null,
                    BLUEZ_SERVICE,
                    object_path,
                    interface_name,
                    null
                );
                
                // Setup properties changed signal
                proxy.g_properties_changed.connect((changed, invalidated) => {
                    on_properties_changed(object_path, interface_name, changed);
                });
                
                // Cache the proxy
                _proxies.insert(proxy_key, proxy);
                
                debug("BlueZClient: Created proxy for %s on %s", interface_name, object_path);
                return proxy;
                
            } catch (Error e) {
                warning("BlueZClient: Failed to create proxy for %s on %s: %s", 
                       interface_name, object_path, e.message);
                throw e;
            }
        }
        
        /**
         * Get all objects implementing a specific interface
         * 
         * @param interface_name The interface name to filter by
         * @return List of object paths
         */
        public GenericArray<string> get_objects_by_interface(string interface_name) {
            var objects = new GenericArray<string>();
            
            if (_object_manager == null) {
                return objects;
            }
            
            var managed_objects = _object_manager.get_objects();
            foreach (var object in managed_objects) {
                var interfaces = object.get_interfaces();
                foreach (var interface_obj in interfaces) {
                    // get_info() returns null for BlueZ interfaces since
                    // DBusObjectManagerClient doesn't have pre-loaded introspection data.
                    // Use the DBusProxy's interface name directly instead.
                    string? iface_name = null;
                    var info = interface_obj.get_info();
                    if (info != null) {
                        iface_name = info.name;
                    } else if (interface_obj is DBusProxy) {
                        iface_name = ((DBusProxy) interface_obj).get_interface_name();
                    }
                    if (iface_name != null && iface_name == interface_name) {
                        objects.add(object.get_object_path());
                        break;
                    }
                }
            }
            
            return objects;
        }
        
        /**
         * Call a D-Bus method asynchronously
         * 
         * @param object_path The D-Bus object path
         * @param interface_name The D-Bus interface name
         * @param method_name The method name to call
         * @param parameters The method parameters (or null)
         * @param timeout_msec Timeout in milliseconds (default: 30000)
         * @return The method return value
         */
        public async Variant call_method(
            string object_path,
            string interface_name,
            string method_name,
            Variant? parameters = null,
            int timeout_msec = 30000
        ) throws Error {
            if (!_is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            try {
                debug("BlueZClient: Calling method %s.%s on %s", 
                      interface_name, method_name, object_path);
                
                var result = yield _connection.call(
                    BLUEZ_SERVICE,
                    object_path,
                    interface_name,
                    method_name,
                    parameters,
                    null,
                    DBusCallFlags.NONE,
                    timeout_msec,
                    null
                );
                
                debug("BlueZClient: Method call successful");
                return result;
                
            } catch (Error e) {
                warning("BlueZClient: Method call failed for %s.%s on %s: %s",
                       interface_name, method_name, object_path, e.message);
                throw e;
            }
        }
        
        /**
         * Get a property value from a D-Bus object
         * 
         * @param object_path The D-Bus object path
         * @param interface_name The D-Bus interface name
         * @param property_name The property name
         * @return The property value
         */
        public async Variant get_property(
            string object_path,
            string interface_name,
            string property_name
        ) throws Error {
            if (!_is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            try {
                debug("BlueZClient: Getting property %s.%s on %s",
                      interface_name, property_name, object_path);
                
                var result = yield _connection.call(
                    BLUEZ_SERVICE,
                    object_path,
                    PROPERTIES_INTERFACE,
                    "Get",
                    new Variant("(ss)", interface_name, property_name),
                    null,
                    DBusCallFlags.NONE,
                    -1,
                    null
                );
                
                Variant value;
                result.get("(v)", out value);
                
                return value;
                
            } catch (Error e) {
                warning("BlueZClient: Failed to get property %s.%s on %s: %s",
                       interface_name, property_name, object_path, e.message);
                throw e;
            }
        }
        
        /**
         * Set a property value on a D-Bus object
         * 
         * @param object_path The D-Bus object path
         * @param interface_name The D-Bus interface name
         * @param property_name The property name
         * @param value The property value
         */
        public async void set_property(
            string object_path,
            string interface_name,
            string property_name,
            Variant value
        ) throws Error {
            if (!_is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            try {
                debug("BlueZClient: Setting property %s.%s on %s",
                      interface_name, property_name, object_path);
                
                yield _connection.call(
                    BLUEZ_SERVICE,
                    object_path,
                    PROPERTIES_INTERFACE,
                    "Set",
                    new Variant("(ssv)", interface_name, property_name, value),
                    null,
                    DBusCallFlags.NONE,
                    -1,
                    null
                );
                
                debug("BlueZClient: Property set successfully");
                
            } catch (Error e) {
                warning("BlueZClient: Failed to set property %s.%s on %s: %s",
                       interface_name, property_name, object_path, e.message);
                throw e;
            }
        }
        
        /**
         * Get all properties from a D-Bus object
         * 
         * @param object_path The D-Bus object path
         * @param interface_name The D-Bus interface name
         * @return Hash table of property names to values
         */
        public async HashTable<string, Variant> get_all_properties(
            string object_path,
            string interface_name
        ) throws Error {
            if (!_is_connected) {
                throw new IOError.NOT_CONNECTED("BlueZ client not connected");
            }
            
            try {
                debug("BlueZClient: Getting all properties for %s on %s",
                      interface_name, object_path);
                
                var result = yield _connection.call(
                    BLUEZ_SERVICE,
                    object_path,
                    PROPERTIES_INTERFACE,
                    "GetAll",
                    new Variant("(s)", interface_name),
                    null,
                    DBusCallFlags.NONE,
                    -1,
                    null
                );
                
                // Manually iterate the a{sv} dict from the (a{sv}) tuple
                var properties = new HashTable<string, Variant>(str_hash, str_equal);
                Variant dict_variant = result.get_child_value(0);
                var iter = dict_variant.iterator();
                string key;
                Variant value;
                while (iter.next("{sv}", out key, out value)) {
                    properties[key] = value;
                }
                
                debug("BlueZClient: Retrieved %u properties", properties.size());
                return properties;
                
            } catch (Error e) {
                warning("BlueZClient: Failed to get all properties for %s on %s: %s",
                       interface_name, object_path, e.message);
                throw e;
            }
        }
        
        /**
         * Subscribe to signals from a D-Bus object
         * 
         * @param object_path The D-Bus object path (or null for all objects)
         * @param interface_name The D-Bus interface name (or null for all interfaces)
         * @param signal_name The signal name (or null for all signals)
         * @param callback The callback to invoke when signal is received
         * @return Subscription ID for unsubscribing
         */
        public uint subscribe_to_signals(
            string? object_path,
            string? interface_name,
            string? signal_name,
            owned DBusSignalCallback callback
        ) {
            if (!_is_connected || _connection == null) {
                warning("BlueZClient: Cannot subscribe to signals - not connected");
                return 0;
            }
            
            uint subscription_id = _next_subscription_id++;
            
            var dbus_subscription_id = _connection.signal_subscribe(
                BLUEZ_SERVICE,
                interface_name,
                signal_name,
                object_path,
                null,
                DBusSignalFlags.NONE,
                callback
            );
            
            var subscription = new SignalSubscription(
                dbus_subscription_id,
                object_path,
                interface_name,
                signal_name
            );
            
            _signal_subscriptions[subscription_id] = subscription;
            
            debug("BlueZClient: Subscribed to signals (ID: %u, interface: %s, signal: %s, object: %s)",
                  subscription_id,
                  interface_name ?? "all",
                  signal_name ?? "all",
                  object_path ?? "all");
            
            return subscription_id;
        }
        
        /**
         * Unsubscribe from signals
         * 
         * @param subscription_id The subscription ID returned by subscribe_to_signals
         */
        public void unsubscribe_from_signals(uint subscription_id) {
            var subscription = _signal_subscriptions.lookup(subscription_id);
            if (subscription == null) {
                warning("BlueZClient: Invalid subscription ID: %u", subscription_id);
                return;
            }
            
            if (_connection != null) {
                _connection.signal_unsubscribe(subscription.dbus_subscription_id);
            }
            
            _signal_subscriptions.remove(subscription_id);
            
            debug("BlueZClient: Unsubscribed from signals (ID: %u)", subscription_id);
        }
        
        /**
         * Handle raw D-Bus PropertiesChanged signal from the global subscription.
         * Signal signature: (sa{sv}as) — interface_name, changed_properties, invalidated_properties
         */
        private void on_dbus_properties_changed(
            DBusConnection connection,
            string? sender,
            string object_path,
            string interface_name,
            string signal_name,
            Variant parameters
        ) {
            // parameters is (sa{sv}as)
            var iface_name = parameters.get_child_value(0).get_string();
            var changed_dict = parameters.get_child_value(1);
            on_properties_changed(object_path, iface_name, changed_dict);
        }
        
        /**
         * Handle properties changed signal
         */
        private void on_properties_changed(
            string object_path,
            string interface_name,
            Variant changed_properties_variant
        ) {
            try {
                var changed_properties = new HashTable<string, Variant>(str_hash, str_equal);
                
                var iter = changed_properties_variant.iterator();
                string key;
                Variant value;
                
                while (iter.next("{sv}", out key, out value)) {
                    changed_properties[key] = value;
                }
                
                if (changed_properties.size() > 0) {
                    debug("BlueZClient: Properties changed on %s (%s): %u properties",
                          object_path, interface_name, changed_properties.size());
                    
                    properties_changed(object_path, interface_name, changed_properties);
                }
                
            } catch (Error e) {
                warning("BlueZClient: Error processing properties changed: %s", e.message);
            }
        }
    }
    
    /**
     * Signal subscription information
     */
    private class SignalSubscription {
        public uint dbus_subscription_id { get; set; }
        public string? object_path { get; set; }
        public string? interface_name { get; set; }
        public string? signal_name { get; set; }
        
        public SignalSubscription(
            uint dbus_subscription_id,
            string? object_path,
            string? interface_name,
            string? signal_name
        ) {
            this.dbus_subscription_id = dbus_subscription_id;
            this.object_path = object_path;
            this.interface_name = interface_name;
            this.signal_name = signal_name;
        }
    }
}
